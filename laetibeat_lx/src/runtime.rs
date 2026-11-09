use std::sync::{Arc, Mutex};

use rquickjs::{Context, Ctx, Function, Runtime};

use crate::error::{LxError, Result};
use crate::import::parse_source_manifest;
use crate::models::{LxMusicInfo, LxSourceDeclaration, LxSourceManifest};

const PRELOAD: &str = include_str!("preload.js");
const MAX_RESULT_BYTES: usize = 2 * 1024 * 1024;

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
                // allow promise jobs queued during initialization.
                drain_jobs(&ctx);
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
        Function::new(ctx.clone(), move |_url: String, _options: String| {
            "{\"ok\":false,\"error\":\"HTTP bridge not implemented yet\"}".to_string()
        })?,
    )?;

    globals.set(
        "__lx_log",
        Function::new(ctx.clone(), move |_level: String, _message: String| {})?,
    )?;

    Ok(())
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
    fn rejects_missing_metadata() {
        assert!(LxRuntime::load("const x = 1;").is_err());
    }
}
