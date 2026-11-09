use crate::models::LxSourceManifest;

const MAX_HEADER_LEN: usize = 16 * 1024;

/// Parse the leading `/* ... */` metadata block used by LX custom sources.
///
/// Only `@name`, `@description`, `@version`, `@author`, and `@homepage` are
/// recognized; unknown fields are ignored. The function is intentionally
/// independent from any third-party source implementation.
pub fn parse_source_manifest(script: &str) -> Option<LxSourceManifest> {
    let start = script.find("/*")?;
    let end = script[start + 2..].find("*/")? + start + 2;
    if end > MAX_HEADER_LEN {
        return None;
    }
    let header = &script[start + 2..end];

    let mut manifest = LxSourceManifest::default();
    for raw_line in header.lines() {
        let line = raw_line.trim().trim_start_matches('*').trim();
        let Some(rest) = line.strip_prefix('@') else {
            continue;
        };
        let Some((key, value)) = rest.split_once(char::is_whitespace) else {
            continue;
        };
        let value = value.trim();
        match key {
            "name" => manifest.name = truncate(value, 24),
            "description" => manifest.description = truncate(value, 36),
            "version" => manifest.version = truncate(value, 36),
            "author" => manifest.author = truncate(value, 56),
            "homepage" => manifest.homepage = truncate(value, 1024),
            _ => {}
        }
    }

    if manifest.name.is_empty() {
        manifest.name = "未命名音源".to_string();
    }
    Some(manifest)
}

fn truncate(value: &str, max_chars: usize) -> String {
    value.chars().take(max_chars).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_metadata_header() {
        let script = r#"/**
 * @name 测试音源
 * @description 只用于测试
 * @version 1.2.3
 * @author someone
 * @homepage https://example.com
 */
const x = 1;
"#;
        let manifest = parse_source_manifest(script).unwrap();
        assert_eq!(manifest.name, "测试音源");
        assert_eq!(manifest.description, "只用于测试");
        assert_eq!(manifest.version, "1.2.3");
        assert_eq!(manifest.author, "someone");
        assert_eq!(manifest.homepage, "https://example.com");
    }

    #[test]
    fn rejects_script_without_header() {
        assert!(parse_source_manifest("const x = 1;").is_none());
    }
}
