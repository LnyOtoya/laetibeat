use base64::engine::general_purpose::STANDARD;
use base64::Engine;

pub fn md5_hex(value: &str) -> String {
    format!("{:x}", md5::compute(value.as_bytes()))
}

pub fn base64_encode(value: &str) -> String {
    STANDARD.encode(value.as_bytes())
}

pub fn base64_decode(value: &str) -> std::result::Result<Vec<u8>, String> {
    STANDARD
        .decode(value)
        .map_err(|error| format!("base64 decode failed: {error}"))
}

/// Decode base64 into a JSON array of bytes for the JS `Uint8Array` bridge.
pub fn base64_decode_json_array(value: &str) -> String {
    match base64_decode(value) {
        Ok(bytes) => serde_json::to_string(&bytes).unwrap_or_else(|_| "[]".to_string()),
        Err(error) => serde_json::json!({ "error": error }).to_string(),
    }
}

/// Encode a JSON array of bytes (or a string) to base64.
pub fn base64_encode_json_or_string(value: &str) -> String {
    if let Ok(bytes) = serde_json::from_str::<Vec<u8>>(value) {
        return STANDARD.encode(bytes);
    }
    base64_encode(value)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn md5_and_base64() {
        assert_eq!(md5_hex("hello"), "5d41402abc4b2a76b9719d911017c592");
        assert_eq!(base64_encode("hello"), "aGVsbG8=");
        assert_eq!(base64_decode("aGVsbG8=").unwrap(), b"hello");
        assert_eq!(
            base64_decode_json_array("aGVsbG8="),
            "[104,101,108,108,111]"
        );
    }
}
