#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ALLOW_DIRTY=0
BUILD=0
TAG=""

usage() {
  cat <<'EOF'
Usage: scripts/release_preflight.sh [vX.Y.Z] [--build] [--allow-dirty]

Checks:
  - pubspec version and versionCode match the tag
  - CHANGELOG has a non-empty section for the tag
  - Go / QQ / NetEase host license files exist
  - working tree is clean (unless --allow-dirty)
  - Flutter analyze/test, cargo test, go test
  - with --build: release split APKs contain all three embedded hosts,
    extractNativeLibs=true, expected versionName/versionCode, and valid signature

This script does NOT create or push a tag.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --build) BUILD=1 ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    -h|--help) usage; exit 0 ;;
    v*) TAG="$arg" ;;
    *) echo "unknown argument: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

PUBSPEC="laetibeat_flutter/pubspec.yaml"
PUB_VERSION="$(sed -n 's/^version:[[:space:]]*//p' "$PUBSPEC" | head -1 | tr -d '\r')"
if [[ -z "$PUB_VERSION" ]]; then
  echo "cannot read version from $PUBSPEC" >&2
  exit 1
fi
VERSION="${PUB_VERSION%%+*}"
BUILD_NO="${PUB_VERSION#*+}"
if [[ "$BUILD_NO" == "$PUB_VERSION" ]]; then
  BUILD_NO=""
fi
if [[ -z "$TAG" ]]; then
  TAG="v${VERSION}"
fi
if [[ "$TAG" != v* ]]; then
  echo "tag must start with v: $TAG" >&2
  exit 1
fi
TAG_VERSION="${TAG#v}"
if ! [[ "$TAG_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "invalid semver tag: $TAG" >&2
  exit 1
fi
IFS=. read -r MAJOR MINOR PATCH <<< "$TAG_VERSION"
EXPECTED_CODE=$((MAJOR * 1000000 + MINOR * 1000 + PATCH))

if [[ "$VERSION" != "$TAG_VERSION" ]]; then
  echo "pubspec version $VERSION does not match tag $TAG_VERSION" >&2
  exit 1
fi
if [[ "$BUILD_NO" != "$EXPECTED_CODE" ]]; then
  echo "pubspec build number '$BUILD_NO' != expected versionCode $EXPECTED_CODE" >&2
  echo "expected: version: ${TAG_VERSION}+${EXPECTED_CODE}" >&2
  exit 1
fi

python3 - "$TAG_VERSION" <<'PY'
import re
import sys
from pathlib import Path

version = sys.argv[1]
text = Path("CHANGELOG.md").read_text(encoding="utf-8")
pattern = re.compile(
    rf"^## \[{re.escape(version)}\] - (\d{{4}}-\d{{2}}-\d{{2}})\n(.*?)(?=^## \[|\Z)",
    re.MULTILINE | re.DOTALL,
)
match = pattern.search(text)
if match is None:
    raise SystemExit(f"CHANGELOG.md missing non-empty [{version}] section")
body = match.group(2).strip()
if not body:
    raise SystemExit(f"CHANGELOG.md [{version}] section is empty")
print(f"CHANGELOG [{version}] - {match.group(1)}: {len(body)} chars")
PY

for file in \
  LICENSE \
  THIRD_PARTY_NOTICES.md \
  laetibeat_musicapi_host/LICENSE \
  laetibeat_musicapi_host/third_party/music-lib/LICENSE \
  laetibeat_musicapi_host/third_party/music-lib/PATCH.md \
  laetibeat_qq_host/LICENSE \
  laetibeat_netease_host/LICENSE \
  laetibeat_netease_host/LICENSE-WTFPL; do
  if [[ ! -s "$file" ]]; then
    echo "missing required release file: $file" >&2
    exit 1
  fi
done

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
  echo "warning: releasing from branch '$BRANCH', not main" >&2
fi
if [[ -n "$(git status --porcelain)" ]]; then
  if [[ "$ALLOW_DIRTY" -ne 1 ]]; then
    echo "working tree is dirty; commit changes first or pass --allow-dirty" >&2
    git status --short >&2
    exit 1
  fi
  echo "warning: working tree is dirty (--allow-dirty)" >&2
fi

for command in flutter cargo go python3 unzip; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "missing command: $command" >&2
    exit 1
  fi
done

echo "== Flutter analyze =="
(cd laetibeat_flutter && flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings)
echo "== Flutter test =="
(cd laetibeat_flutter && flutter test --no-pub)
echo "== Rust test =="
cargo test --workspace
echo "== Go test =="
(cd laetibeat_musicapi_host && go test ./...)

if [[ "$BUILD" -eq 1 ]]; then
  echo "== Release split APK build =="
  (
    cd laetibeat_flutter
    flutter build apk --release --split-per-abi \
      --build-name="$TAG_VERSION" \
      --build-number="$EXPECTED_CODE"
  )

  APK_DIR="laetibeat_flutter/build/app/outputs/flutter-apk"
  # Flutter 的 --split-per-abi 会在 base versionCode 上叠加 ABI offset。
  declare -A ABI_VERSION_OFFSET=(
    [arm64-v8a]=2000
    [armeabi-v7a]=1000
    [x86_64]=4000
  )
  AAPT2="$(find "${ANDROID_HOME:-$HOME/Android/Sdk}/build-tools" -name aapt2 2>/dev/null | sort | tail -1)"
  for ABI in arm64-v8a armeabi-v7a x86_64; do
    APK="$APK_DIR/app-${ABI}-release.apk"
    if [[ ! -f "$APK" ]]; then
      echo "missing APK: $APK" >&2
      exit 1
    fi
    for host_so in \
      liblaetibeat_musicapi_host.so \
      liblaetibeat_qq_host.so \
      liblaetibeat_netease_host.so; do
      if ! unzip -l "$APK" | grep "lib/${ABI}/${host_so}" >/dev/null; then
        echo "APK missing embedded host ${host_so}: $APK" >&2
        exit 1
      fi
    done
    expected_abi_code=$((EXPECTED_CODE + ABI_VERSION_OFFSET[$ABI]))
    if [[ -n "$AAPT2" ]]; then
      MANIFEST="$("$AAPT2" dump xmltree "$APK" --file AndroidManifest.xml)"
      if ! grep -q 'extractNativeLibs.*=true' <<< "$MANIFEST"; then
        echo "extractNativeLibs=true missing from $APK" >&2
        exit 1
      fi
      BADGING="$("$AAPT2" dump badging "$APK")"
      if ! grep -q "versionCode='${expected_abi_code}'" <<< "$BADGING"; then
        echo "unexpected versionCode in $APK (expected ${expected_abi_code})" >&2
        echo "$BADGING" | head -3 >&2
        exit 1
      fi
      if ! grep -q "versionName='${TAG_VERSION}'" <<< "$BADGING"; then
        echo "unexpected versionName in $APK" >&2
        echo "$BADGING" | head -3 >&2
        exit 1
      fi
      echo "aapt2: ${ABI} versionName=${TAG_VERSION}, versionCode=${expected_abi_code}, extractNativeLibs=true"
    fi
  done
  if [[ -z "$AAPT2" ]]; then
    echo "warning: aapt2 not found; skip manifest/version checks" >&2
  fi

  APKSIGNER="$(find "${ANDROID_HOME:-$HOME/Android/Sdk}/build-tools" -name apksigner 2>/dev/null | sort | tail -1)"
  if [[ -z "$APKSIGNER" ]]; then
    echo "warning: apksigner not found; skip signature checks" >&2
  else
    "$APKSIGNER" verify --print-certs "$APK_DIR/app-arm64-v8a-release.apk" | sed -n '1,3p'
  fi
fi

echo
echo "Preflight OK for ${TAG}."
echo "Next (not executed by this script):"
echo "  git tag -a ${TAG} -m \"Laetibeat ${TAG_VERSION}\""
echo "  git push origin ${TAG}"
