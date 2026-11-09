'use strict';

/*
 * Minimal LX custom-source compatibility layer.
 *
 * This is an independent implementation of the public event shape used by
 * LX custom sources. Host callbacks are injected by laetibeat_lx before this
 * file is evaluated.
 */
(function () {
  const EVENT_NAMES = {
    request: 'request',
    inited: 'inited',
    updateAlert: 'updateAlert',
  };

  const events = { request: null };
  let inited = false;
  let updateAlertShown = false;

  const native = {
    inited: globalThis.__lx_on_inited,
    updateAlert: globalThis.__lx_on_update_alert,
    request: globalThis.__lx_request,
    log: globalThis.__lx_log,
    md5: globalThis.__lx_md5,
    b64Encode: globalThis.__lx_b64_encode,
    b64Decode: globalThis.__lx_b64_decode,
    b64EncodeBytes: globalThis.__lx_b64_encode_bytes,
    aesEncrypt: globalThis.__lx_aes_encrypt,
    rsaEncrypt: globalThis.__lx_rsa_encrypt,
  };

  delete globalThis.__lx_on_inited;
  delete globalThis.__lx_on_update_alert;
  delete globalThis.__lx_request;
  delete globalThis.__lx_log;
  delete globalThis.__lx_md5;
  delete globalThis.__lx_b64_encode;
  delete globalThis.__lx_b64_decode;
  delete globalThis.__lx_b64_encode_bytes;
  delete globalThis.__lx_aes_encrypt;
  delete globalThis.__lx_rsa_encrypt;

  function callLog(level, message) {
    try {
      native.log(level, String(message));
    } catch (_) {
      // Logging must never break source execution.
    }
  }

  function send(eventName, data) {
    return new Promise(function (resolve, reject) {
      if (!Object.values(EVENT_NAMES).includes(eventName)) {
        reject(new Error('unsupported event: ' + eventName));
        return;
      }
      if (eventName === EVENT_NAMES.inited) {
        if (inited) {
          reject(new Error('source already initialized'));
          return;
        }
        inited = true;
        try {
          native.inited(JSON.stringify(data || {}));
          resolve();
        } catch (error) {
          reject(error);
        }
        return;
      }
      if (eventName === EVENT_NAMES.updateAlert) {
        if (updateAlertShown) {
          reject(new Error('update alert can only be sent once'));
          return;
        }
        updateAlertShown = true;
        try {
          native.updateAlert(JSON.stringify(data || {}));
          resolve();
        } catch (error) {
          reject(error);
        }
        return;
      }
      reject(new Error('unsupported event: ' + eventName));
    });
  }

  function on(eventName, handler) {
    if (eventName !== EVENT_NAMES.request) {
      return Promise.reject(new Error('unsupported event: ' + eventName));
    }
    if (typeof handler !== 'function') {
      return Promise.reject(new Error('request handler must be a function'));
    }
    events.request = handler;
    return Promise.resolve();
  }

  function request(url, options, callback) {
    if (typeof callback !== 'function') {
      throw new Error('callback must be a function');
    }
    let result;
    try {
      result = JSON.parse(native.request(String(url), JSON.stringify(options || {})));
    } catch (error) {
      callback(error, null, null);
      return function () {};
    }
    if (!result || result.ok !== true) {
      callback(new Error(result && result.error ? result.error : 'request failed'), null, null);
      return function () {};
    }
    const response = result.response || {};
    let body = response.body;
    if (response.binary && response.bodyBase64) {
      const decoded = JSON.parse(native.b64Decode(response.bodyBase64));
      if (decoded && decoded.error) {
        callback(new Error(decoded.error), null, null);
        return function () {};
      }
      body = new Uint8Array(decoded);
    }
    callback(null, {
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      headers: response.headers || {},
      body: body,
    }, body);
    return function () {};
  }

  function stringToBytes(value) {
    const bytes = [];
    for (let i = 0; i < value.length; i += 1) {
      const code = value.charCodeAt(i);
      if (code < 0x80) {
        bytes.push(code);
      } else if (code < 0x800) {
        bytes.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
      } else {
        bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
      }
    }
    return bytes;
  }

  function bytesToString(bytes) {
    let result = '';
    for (let i = 0; i < bytes.length; i += 1) {
      const byte = bytes[i] & 0xff;
      if (byte < 0x80) {
        result += String.fromCharCode(byte);
      } else if (byte < 0xe0) {
        result += String.fromCharCode(((byte & 0x1f) << 6) | (bytes[i + 1] & 0x3f));
        i += 1;
      } else {
        result += String.fromCharCode(
          ((byte & 0x0f) << 12) |
            ((bytes[i + 1] & 0x3f) << 6) |
            (bytes[i + 2] & 0x3f),
        );
        i += 2;
      }
    }
    return result;
  }

  function dataToB64(data) {
    if (typeof data === 'string') return native.b64Encode(data);
    if (Array.isArray(data) || ArrayBuffer.isView(data)) {
      const bytes = ArrayBuffer.isView(data) ? Array.from(data) : data;
      return native.b64EncodeBytes(JSON.stringify(bytes));
    }
    throw new Error('unsupported data type for base64 conversion');
  }

  const utils = {
    buffer: {
      from(input, encoding) {
        if (typeof input === 'string') {
          if (encoding === 'base64') {
            const decoded = JSON.parse(native.b64Decode(input));
            if (decoded && decoded.error) throw new Error(decoded.error);
            return new Uint8Array(decoded);
          }
          if (encoding === 'hex') {
            return new Uint8Array(input.match(/.{1,2}/g).map((byte) => parseInt(byte, 16)));
          }
          return new Uint8Array(stringToBytes(input));
        }
        if (Array.isArray(input)) return new Uint8Array(input);
        if (ArrayBuffer.isView(input)) return new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
        throw new Error('unsupported buffer input');
      },
      bufToString(input, format) {
        const bytes = ArrayBuffer.isView(input) ? Array.from(input) : input;
        if (!Array.isArray(bytes)) throw new Error('unsupported buffer input');
        if (format === 'base64') return native.b64EncodeBytes(JSON.stringify(bytes));
        if (format === 'hex') return bytes.map((byte) => (byte & 0xff).toString(16).padStart(2, '0')).join('');
        return bytesToString(bytes);
      },
    },
    crypto: {
      aesEncrypt(buffer, mode, key, iv) {
        const result = JSON.parse(
          native.aesEncrypt(dataToB64(buffer), mode, dataToB64(key), iv == null ? '' : dataToB64(iv)),
        );
        if (!result || result.ok !== true) {
          throw new Error(result && result.error ? result.error : 'AES encryption failed');
        }
        const decoded = JSON.parse(native.b64Decode(result.data));
        if (decoded && decoded.error) throw new Error(decoded.error);
        return new Uint8Array(decoded);
      },
      rsaEncrypt(buffer, key) {
        if (typeof key !== 'string') throw new Error('RSA key must be a string');
        const result = JSON.parse(native.rsaEncrypt(dataToB64(buffer), key));
        if (!result || result.ok !== true) {
          throw new Error(result && result.error ? result.error : 'RSA encryption failed');
        }
        const decoded = JSON.parse(native.b64Decode(result.data));
        if (decoded && decoded.error) throw new Error(decoded.error);
        return new Uint8Array(decoded);
      },
      md5(value) {
        if (typeof value !== 'string') throw new Error('md5 expects a string');
        return native.md5(value);
      },
      randomBytes(size) {
        const bytes = new Uint8Array(size);
        for (let i = 0; i < size; i += 1) bytes[i] = Math.floor(Math.random() * 256);
        return bytes;
      },
    },
  };

  const timers = new Map();
  let nextTimerId = 1;
  const MAX_TIMERS = 256;
  const MAX_TIMER_DELAY = 60_000;

  function setTimeout(callback, delay, ...args) {
    if (typeof callback !== 'function') throw new Error('setTimeout callback must be a function');
    if (timers.size >= MAX_TIMERS) throw new Error('too many timers');
    const id = nextTimerId++;
    const wait = Math.max(0, Math.min(Number(delay) || 0, MAX_TIMER_DELAY));
    timers.set(id, { due: Date.now() + wait, callback, args });
    return id;
  }

  function clearTimeout(id) {
    timers.delete(id);
  }

  globalThis.setTimeout = setTimeout;
  globalThis.clearTimeout = clearTimeout;

  // Host pumping hooks. The Rust side sleeps only until the next due timer,
  // then asks JS to run all timers whose deadline has arrived.
  globalThis.__lx_next_timer_delay = function () {
    if (timers.size === 0) return -1;
    let earliest = Infinity;
    for (const timer of timers.values()) earliest = Math.min(earliest, timer.due);
    return Math.max(0, earliest - Date.now());
  };

  globalThis.__lx_run_due_timers = function () {
    const now = Date.now();
    const due = [];
    for (const [id, timer] of timers) {
      if (timer.due <= now) due.push([id, timer]);
    }
    for (const [id, timer] of due) {
      timers.delete(id);
      try {
        timer.callback(...timer.args);
      } catch (error) {
        callLog('error', error && error.message ? error.message : String(error));
      }
    }
    return due.length;
  };

  globalThis.lx = {
    EVENT_NAMES: EVENT_NAMES,
    on: on,
    send: send,
    request: request,
    utils: utils,
    version: '2.0.0',
    env: 'mobile',
  };

  // The host calls this to dispatch lx.on('request').
  globalThis.__lx_dispatch = function (source, action, infoJson) {
    globalThis.__lx_result = undefined;
    const handler = events.request;
    if (!handler) {
      globalThis.__lx_result = JSON.stringify({ ok: false, error: 'request not handled' });
      return false;
    }
    let value;
    try {
      value = handler.call(globalThis.lx, {
        source: source,
        action: action,
        info: {
          type: globalThis.__lx_quality || '',
          musicInfo: JSON.parse(infoJson),
        },
      });
    } catch (error) {
      globalThis.__lx_result = JSON.stringify({
        ok: false,
        error: error && error.message ? error.message : String(error),
      });
      return true;
    }
    Promise.resolve(value).then(
      function (result) {
        globalThis.__lx_result = JSON.stringify({ ok: true, value: result });
      },
      function (error) {
        globalThis.__lx_result = JSON.stringify({
          ok: false,
          error: error && error.message ? error.message : String(error),
        });
      },
    );
    return true;
  };

  globalThis.eval = function () {
    throw new Error('eval is not available');
  };

  try {
    Object.freeze(globalThis.lx);
    Object.freeze(globalThis.lx.EVENT_NAMES);
    callLog('info', 'LX preload ready');
  } catch (_) {
    // Freezing is best effort; the host still owns the sandbox.
  }
})();
