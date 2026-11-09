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
  };

  delete globalThis.__lx_on_inited;
  delete globalThis.__lx_on_update_alert;
  delete globalThis.__lx_request;
  delete globalThis.__lx_log;
  delete globalThis.__lx_md5;
  delete globalThis.__lx_b64_encode;
  delete globalThis.__lx_b64_decode;
  delete globalThis.__lx_b64_encode_bytes;

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
    globalThis.__lx_result = JSON.stringify({ ok: false, error: 'request not handled' });
    const handler = events.request;
    if (!handler) return false;
    let value;
    try {
      value = handler.call(globalThis.lx, {
        source: source,
        action: action,
        info: JSON.parse(infoJson),
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
