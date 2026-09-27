#!/usr/bin/env bash
# Build helper for Abidjan Runner. Usage: tools/build.sh [windows|linux|android|all]
set -e
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"

GODOT="${GODOT:-godot}"
VERSION="4.4.1.stable"
TPL_DIR="$HOME/.local/share/godot/export_templates/$VERSION"

install_templates() {
  if [ -f "$TPL_DIR/linux_release.x86_64" ] || [ -f "$TPL_DIR/windows_release_x86_64.exe" ]; then
    echo "[templates] already installed"
    return
  fi
  echo "[templates] downloading export templates..."
  TPZ="/tmp/godot_templates.tpz"
  curl -sSL -o "$TPZ" "https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_export_templates.tpz"
  mkdir -p "$TPL_DIR"
  TMP="$(mktemp -d)"
  unzip -q "$TPZ" -d "$TMP"
  cp "$TMP/templates/"* "$TPL_DIR/"
  rm -rf "$TMP" "$TPZ"
  echo "[templates] installed to $TPL_DIR"
}

export_one() {
  local preset="$1" out="$2"
  mkdir -p "$(dirname "$out")"
  echo "[export] $preset -> $out"
  "$GODOT" --headless --path "$HERE" --export-release "$preset" "$out"
}

install_templates

export_apk() {
  # Try a release-signed APK; if no release keystore is configured, fall back to
  # a debug-signed APK (installs on any device). Needs a valid Android SDK with
  # apksigner + zipalign, plus the debug keystore set in Godot's Editor Settings.
  mkdir -p builds/android
  echo "[export] Android -> builds/android/AbidjanRunner.apk"
  if ! "$GODOT" --headless --path "$HERE" --export-release "Android" "builds/android/AbidjanRunner.apk" 2>/dev/null; then
    echo "[export] release keystore missing -> building debug-signed APK"
    "$GODOT" --headless --path "$HERE" --export-debug "Android" "builds/android/AbidjanRunner.apk"
  fi
}

case "${1:-all}" in
  windows) export_one "Windows Desktop" "builds/windows/AbidjanRunner.exe" ;;
  linux)   export_one "Linux"           "builds/linux/AbidjanRunner.x86_64" ;;
  android) export_apk ;;
  all)
    export_one "Windows Desktop" "builds/windows/AbidjanRunner.exe"
    export_one "Linux"           "builds/linux/AbidjanRunner.x86_64"
    ;;
esac
echo "[done]"
