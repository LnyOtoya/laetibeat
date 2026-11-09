use aes::cipher::block_padding::Pkcs7;
use aes::cipher::generic_array::GenericArray;
use aes::cipher::{BlockEncryptMut, KeyInit, KeyIvInit};
use aes::Aes128;
use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use cbc::Encryptor;
use rsa::pkcs1::DecodeRsaPublicKey;
use rsa::pkcs8::DecodePublicKey;
use rsa::traits::PublicKeyParts;
use rsa::{BoxedUint, PublicKey};

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

/// AES-128-ECB with PKCS#7 padding, returned as uppercase hex. WY's eapi
/// request params use this encoding.
pub fn aes_ecb_pkcs7_hex(data: &[u8], key: &[u8]) -> std::result::Result<String, String> {
    if key.len() != 16 {
        return Err("AES-128 key must be 16 bytes".to_string());
    }
    let cipher = Aes128::new_from_slice(key).map_err(|error| error.to_string())?;
    let encrypted = cipher.encrypt_padded_vec_mut::<Pkcs7>(data);
    Ok(encrypted
        .iter()
        .map(|byte| format!("{byte:02X}"))
        .collect::<String>())
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

    #[test]
    fn aes_128_ecb_known_vector() {
        let key = hex_bytes("000102030405060708090a0b0c0d0e0f");
        let plaintext = hex_bytes("00112233445566778899aabbccddeeff");
        let expected = hex_bytes("69c4e0d86a7b0430d8cdb78070b4c55a");
        let encrypted = aes_encrypt(
            &STANDARD.encode(plaintext),
            "aes-128-ecb",
            &STANDARD.encode(key),
            "",
        )
        .unwrap();
        assert_eq!(STANDARD.decode(encrypted).unwrap(), expected);
    }

    #[test]
    fn rsa_rejects_invalid_key() {
        assert!(rsa_encrypt(&STANDARD.encode(b"hello"), "not a key").is_err());
    }

    fn hex_bytes(value: &str) -> Vec<u8> {
        value
            .as_bytes()
            .chunks(2)
            .map(|pair| {
                let text = std::str::from_utf8(pair).unwrap();
                u8::from_str_radix(text, 16).unwrap()
            })
            .collect()
    }
}

/// AES encryption compatible with the two modes used by LX sources.
///
/// Inputs and the result are base64 strings because that is the boundary used
/// by the JS `utils.buffer` adapter. `aes-128-cbc` uses PKCS#7 padding;
/// `aes-128-ecb` uses no padding and therefore requires a block-aligned input.
pub fn aes_encrypt(
    data_b64: &str,
    mode: &str,
    key_b64: &str,
    iv_b64: &str,
) -> std::result::Result<String, String> {
    let data = base64_decode(data_b64)?;
    let key = base64_decode(key_b64)?;
    if key.len() != 16 {
        return Err("AES-128 key must be 16 bytes".to_string());
    }

    let encrypted = match mode {
        "aes-128-cbc" => {
            let iv = base64_decode(iv_b64)?;
            if iv.len() != 16 {
                return Err("AES-CBC IV must be 16 bytes".to_string());
            }
            let cipher = Encryptor::<Aes128>::new_from_slices(&key, &iv)
                .map_err(|error| error.to_string())?;
            cipher.encrypt_padded_vec_mut::<Pkcs7>(&data)
        }
        "aes-128-ecb" => {
            if data.len() % 16 != 0 {
                return Err("AES-ECB input must be block aligned".to_string());
            }
            let mut cipher = Aes128::new_from_slice(&key).map_err(|error| error.to_string())?;
            let mut output = data;
            for chunk in output.chunks_mut(16) {
                let mut block = GenericArray::clone_from_slice(chunk);
                cipher.encrypt_block_mut(&mut block);
                chunk.copy_from_slice(&block);
            }
            output
        }
        other => return Err(format!("unsupported AES mode: {other}")),
    };

    Ok(STANDARD.encode(encrypted))
}

/// Raw RSA public-key encryption with no padding, matching the LX source
/// utility's `rsaEncrypt` behavior. The key may be a PEM public key or the
/// bare base64 body commonly embedded in source scripts.
pub fn rsa_encrypt(data_b64: &str, public_key: &str) -> std::result::Result<String, String> {
    let data = base64_decode(data_b64)?;
    let pem = normalize_public_key(public_key);
    let key = PublicKey::from_public_key_pem(&pem)
        .or_else(|_| PublicKey::from_pkcs1_pem(&pem))
        .map_err(|error| format!("invalid RSA public key: {error}"))?;
    if data.len() > key.size() {
        return Err("RSA input is too large for the public key".to_string());
    }

    let message = BoxedUint::from_be_slice_vartime(&data);
    let encrypted = rsa::hazmat::rsa_encrypt(&key, &message)
        .map_err(|error| format!("RSA encryption failed: {error}"))?;
    let mut bytes = encrypted.to_be_bytes().to_vec();
    if bytes.len() < key.size() {
        let mut padded = vec![0_u8; key.size() - bytes.len()];
        padded.extend_from_slice(&bytes);
        bytes = padded;
    }
    Ok(STANDARD.encode(bytes))
}

fn normalize_public_key(key: &str) -> String {
    let trimmed = key.trim();
    if trimmed.contains("BEGIN PUBLIC KEY") || trimmed.contains("BEGIN RSA PUBLIC KEY") {
        return trimmed.to_string();
    }
    let body = trimmed.split_whitespace().collect::<String>();
    format!("-----BEGIN PUBLIC KEY-----\n{body}\n-----END PUBLIC KEY-----")
}
