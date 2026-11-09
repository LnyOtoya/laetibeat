use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use rquickjs::{Context, Ctx, Function, Runtime};

use crate::error::{LxError, Result};
use crate::http;
use crate::import::parse_source_manifest;
use crate::models::{LxMusicInfo, LxSourceDeclaration, LxSourceManifest};
use crate::utils;

const PRELOAD: &str = include_str!("preload.js");
const MAX_RESULT_BYTES: usize = 2 * 1024 * 1024;
const TIMER_PUMP_LIMIT: Duration = Duration::from_secs(5);

/// A loaded LX source script and the capabilities it declared.
///
/// The QuickJS runtime is kept alive, but a fresh context is created for each
/// operation in this first milestone. A later revision should keep one
/// long-lived context per source on a dedicated JS thread.
pub struct LxRuntime {
    runtime: Runtime,
    script: String,
    manifest: LxSourceManifest,
    declaration: LxSourceDeclaration,
}

impl LxRuntime {
    /// Load a source script through the compatibility preload and require a
    /// successful `inited` declaration before returning.
    pub fn load(script: &str) -> Result<Self> {
        let manifest = parse_source_manifest(script)
            .ok_or_else(|| LxError::InvalidSource("missing metadata header".to_string()))?;
        if script.len() > 4 * 1024 * 1024 {
            return Err(LxError::InvalidSource("script is too large".to_string()));
        }

        let runtime = Runtime::new().map_err(|error| LxError::Js(error.to_string()))?;
        let declaration_slot = Arc::new(Mutex::new(None::<String>));
        let declaration = {
            let context = Context::full(&runtime)?;
            context.with(|ctx| {
                install_host(&ctx, declaration_slot.clone())?;
                ctx.eval::<(), _>(PRELOAD)?;
                ctx.eval::<(), _>(script)?;
                // Source scripts normally call send(inited) synchronously, but
                // allow promise jobs and short timers queued during init.
                drain_jobs(&ctx);
                pump_timers(&ctx);
                let raw = declaration_slot
                    .lock()
                    .map_err(|_| LxError::Init("declaration lock poisoned".to_string()))?
                    .clone()
                    .ok_or_else(|| LxError::Init("source did not send inited".to_string()))?;
                parse_declaration(&raw)
            })?
        };

        Ok(Self {
            runtime,
            script: script.to_string(),
            manifest,
            declaration,
        })
    }

    pub fn manifest(&self) -> &LxSourceManifest {
        &self.manifest
    }

    pub fn declaration(&self) -> &LxSourceDeclaration {
        &self.declaration
    }

    /// Resolve a `musicUrl` action. HTTP is intentionally not implemented in
    /// this milestone; a source that only uses static data can already be
    /// exercised end-to-end.
    pub fn resolve_music_url(&self, info: &LxMusicInfo, quality: &str) -> Result<String> {
        let value = self.dispatch("musicUrl", info, quality)?;
        let url = value
            .as_str()
            .ok_or_else(|| LxError::InvalidResponse("musicUrl is not a string".to_string()))?;
        if url.len() > 2048 || !(url.starts_with("http://") || url.starts_with("https://")) {
            return Err(LxError::InvalidResponse("invalid music URL".to_string()));
        }
        Ok(url.to_string())
    }

    fn dispatch(
        &self,
        action: &str,
        info: &LxMusicInfo,
        quality: &str,
    ) -> Result<serde_json::Value> {
        let context = Context::full(&self.runtime)?;
        context.with(|ctx| {
            let declaration_slot = Arc::new(Mutex::new(None));
            install_host(&ctx, declaration_slot)?;
            ctx.eval::<(), _>(PRELOAD)?;
            ctx.eval::<(), _>(self.script.as_str())?;
            drain_jobs(&ctx);

            let globals = ctx.globals();
            globals.set("__lx_source", info.source.clone())?;
            globals.set("__lx_action", action.to_string())?;
            globals.set(
                "__lx_info_json",
                serde_json::to_string(info).map_err(|error| {
                    LxError::InvalidResponse(format!("music info serialization failed: {error}"))
                })?,
            )?;
            globals.set("__lx_quality", quality.to_string())?;
            globals.set("__lx_result", rquickjs::Undefined)?;
            ctx.eval::<(), _>(
                "__lx_dispatch(globalThis.__lx_source, globalThis.__lx_action, globalThis.__lx_info_json)",
            )?;
            drain_jobs(&ctx);
            pump_timers(&ctx);

            let raw: Option<String> = ctx.eval("globalThis.__lx_result")?;
            let raw = raw.ok_or_else(|| {
                LxError::InvalidResponse("source did not produce a result".to_string())
            })?;
            if raw.len() > MAX_RESULT_BYTES {
                return Err(LxError::InvalidResponse("source result is too large".to_string()));
            }
            let parsed: serde_json::Value = serde_json::from_str(&raw)
                .map_err(|error| LxError::InvalidResponse(error.to_string()))?;
            if parsed.get("ok").and_then(|value| value.as_bool()) != Some(true) {
                let message = parsed
                    .get("error")
                    .and_then(|value| value.as_str())
                    .unwrap_or("source rejected request");
                return Err(LxError::Request(message.to_string()));
            }
            Ok(parsed.get("value").cloned().unwrap_or(serde_json::Value::Null))
        })
    }
}

fn install_host(ctx: &Ctx<'_>, declaration_slot: Arc<Mutex<Option<String>>>) -> Result<()> {
    let globals = ctx.globals();

    globals.set(
        "__lx_on_inited",
        Function::new(ctx.clone(), move |raw: String| {
            if raw.len() > 1024 * 1024 {
                return;
            }
            if let Ok(mut slot) = declaration_slot.lock() {
                *slot = Some(raw);
            }
        })?,
    )?;

    globals.set(
        "__lx_on_update_alert",
        Function::new(ctx.clone(), move |_raw: String| {})?,
    )?;

    globals.set(
        "__lx_request",
        Function::new(ctx.clone(), move |url: String, options: String| {
            http::execute(&url, &options)
        })?,
    )?;

    globals.set(
        "__lx_md5",
        Function::new(ctx.clone(), move |value: String| utils::md5_hex(&value))?,
    )?;

    globals.set(
        "__lx_aes_encrypt",
        Function::new(
            ctx.clone(),
            move |data: String, mode: String, key: String, iv: String| match utils::aes_encrypt(
                &data, &mode, &key, &iv,
            ) {
                Ok(data) => serde_json::json!({ "ok": true, "data": data }).to_string(),
                Err(error) => serde_json::json!({ "ok": false, "error": error }).to_string(),
            },
        )?,
    )?;

    globals.set(
        "__lx_rsa_encrypt",
        Function::new(
            ctx.clone(),
            move |data: String, key: String| match utils::rsa_encrypt(&data, &key) {
                Ok(data) => serde_json::json!({ "ok": true, "data": data }).to_string(),
                Err(error) => serde_json::json!({ "ok": false, "error": error }).to_string(),
            },
        )?,
    )?;

    globals.set(
        "__lx_b64_encode",
        Function::new(ctx.clone(), move |value: String| {
            utils::base64_encode(&value)
        })?,
    )?;

    globals.set(
        "__lx_b64_decode",
        Function::new(ctx.clone(), move |value: String| {
            utils::base64_decode_json_array(&value)
        })?,
    )?;

    globals.set(
        "__lx_b64_encode_bytes",
        Function::new(ctx.clone(), move |value: String| {
            utils::base64_encode_json_or_string(&value)
        })?,
    )?;

    globals.set(
        "__lx_log",
        Function::new(ctx.clone(), move |_level: String, _message: String| {})?,
    )?;

    Ok(())
}

/// Run queued JS timers until none remain or the pump budget expires.
///
/// This is deliberately bounded: a source cannot keep the host thread alive
/// forever with a long timer. A later async runtime can replace this with a
/// real event loop.
fn pump_timers(ctx: &Ctx<'_>) {
    let started = Instant::now();
    loop {
        let delay: i64 = match ctx.eval("globalThis.__lx_next_timer_delay()") {
            Ok(delay) => delay,
            Err(_) => return,
        };
        if delay < 0 {
            return;
        }
        let remaining = TIMER_PUMP_LIMIT.saturating_sub(started.elapsed());
        if remaining.is_zero() {
            return;
        }
        let wait = Duration::from_millis(delay.max(0) as u64).min(remaining);
        if !wait.is_zero() {
            std::thread::sleep(wait);
        }
        if ctx
            .eval::<i64, _>("globalThis.__lx_run_due_timers()")
            .is_err()
        {
            return;
        }
        drain_jobs(ctx);
    }
}

fn parse_declaration(raw: &str) -> Result<LxSourceDeclaration> {
    let declaration: LxSourceDeclaration = serde_json::from_str(raw)
        .map_err(|error| LxError::Init(format!("invalid inited payload: {error}")))?;
    if declaration.sources.is_empty() {
        return Err(LxError::Init(
            "inited declared no music sources".to_string(),
        ));
    }
    Ok(declaration)
}

fn drain_jobs(ctx: &Ctx<'_>) {
    // QuickJS returns false when no pending promise job remains. A job that
    // throws is recorded on the context; the next JS call/eval surfaces it.
    while ctx.execute_pending_job() {}
}

#[cfg(test)]
mod tests {
    use super::*;

    const TEST_SOURCE: &str = r#"/**
 * @name Test Source
 * @description Test music source
 * @version 1.0.0
 * @author laetibeat
 */
const { EVENT_NAMES, on, send } = globalThis.lx;

on(EVENT_NAMES.request, ({ source, action, info }) => {
  if (action === 'musicUrl' && source === 'kw') {
    return Promise.resolve('https://example.com/test.mp3');
  }
  return Promise.reject(new Error('unsupported'));
});

send(EVENT_NAMES.inited, {
  sources: {
    kw: {
      type: 'music',
      actions: ['musicUrl'],
      qualitys: ['128k', '320k']
    }
  }
});
"#;

    #[test]
    fn loads_source_and_resolves_url() {
        let runtime = LxRuntime::load(TEST_SOURCE).unwrap();
        assert_eq!(runtime.manifest().name, "Test Source");
        assert!(runtime.declaration().sources.contains_key("kw"));
        let info = LxMusicInfo {
            source: "kw".to_string(),
            id: "123".to_string(),
            name: "Song".to_string(),
            singer: vec!["Artist".to_string()],
            album: String::new(),
            album_id: String::new(),
            interval: 0,
            img: None,
        };
        let url = runtime.resolve_music_url(&info, "320k").unwrap();
        assert_eq!(url, "https://example.com/test.mp3");
    }

    #[test]
    fn lx_request_uses_http_bridge() {
        use std::io::{Read, Write};
        use std::net::TcpListener;
        use std::thread;

        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap();
        let server = thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            let mut buffer = [0_u8; 2048];
            let _ = stream.read(&mut buffer);
            let body = r#"{"url":"https://example.com/from-http.mp3"}"#;
            write!(
                stream,
                "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                body.len(),
                body
            )
            .unwrap();
        });

        let source = r#"/**
 * @name HTTP Test Source
 * @description Test HTTP bridge
 * @version 1.0.0
 * @author laetibeat
 */
const { EVENT_NAMES, on, send, request } = globalThis.lx;

on(EVENT_NAMES.request, ({ source, action }) => {
  if (action !== 'musicUrl') return Promise.reject(new Error('unsupported'));
  return new Promise((resolve, reject) => {
    request('__URL__', { method: 'get' }, (error, response, body) => {
      if (error) return reject(error);
      if (!response || response.statusCode !== 200) return reject(new Error('bad status'));
      resolve(body.url);
    });
  });
});

send(EVENT_NAMES.inited, {
  sources: {
    kw: { type: 'music', actions: ['musicUrl'], qualitys: ['128k'] }
  }
});
"#
        .replace("__URL__", &format!("http://{address}/resolve"));

        let runtime = LxRuntime::load(&source).unwrap();
        let info = LxMusicInfo {
            source: "kw".to_string(),
            id: "123".to_string(),
            name: "Song".to_string(),
            singer: vec!["Artist".to_string()],
            album: String::new(),
            album_id: String::new(),
            interval: 0,
            img: None,
        };
        let url = runtime.resolve_music_url(&info, "128k").unwrap();
        assert_eq!(url, "https://example.com/from-http.mp3");
        server.join().unwrap();
    }

    #[test]
    fn resolves_after_set_timeout() {
        let source = r#"/**
 * @name Timer Test
 * @description Timer source
 * @version 1.0.0
 * @author laetibeat
 */
const { EVENT_NAMES, on, send } = globalThis.lx;

on(EVENT_NAMES.request, ({ action }) => {
  if (action !== 'musicUrl') return Promise.reject(new Error('unsupported'));
  return new Promise((resolve) => {
    setTimeout(() => resolve('https://example.com/timer.mp3'), 10);
  });
});

send(EVENT_NAMES.inited, {
  sources: {
    kw: { type: 'music', actions: ['musicUrl'], qualitys: ['128k'] }
  }
});
"#;
        let runtime = LxRuntime::load(source).unwrap();
        let info = LxMusicInfo {
            source: "kw".to_string(),
            id: "timer".to_string(),
            name: "Timer".to_string(),
            singer: Vec::new(),
            album: String::new(),
            album_id: String::new(),
            interval: 0,
            img: None,
        };
        assert_eq!(
            runtime.resolve_music_url(&info, "128k").unwrap(),
            "https://example.com/timer.mp3"
        );
    }

    #[test]
    fn rejects_missing_metadata() {
        assert!(LxRuntime::load("const x = 1;").is_err());
    }
}
