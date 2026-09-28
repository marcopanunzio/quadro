#!/usr/bin/env bash
# Compila e assembla build/Quadro.app, poi lo firma.
# Uso: scripts/bundle.sh [debug|release]
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Quadro.app"
IDENTITY="${SIGN_IDENTITY:-Personal Dashboard Dev}"

swift build -c "$CONFIG" --product Quadro --package-path "$ROOT"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path --package-path "$ROOT")"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Quadro" "$APP/Contents/MacOS/"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"

if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
    codesign --force --sign "$IDENTITY" --entitlements "$ROOT/Resources/Quadro.entitlements" "$APP"
else
    echo "attenzione: identità \"$IDENTITY\" non trovata, uso firma ad-hoc." >&2
    echo "  macOS potrebbe richiedere di nuovo i permessi a ogni build: vedi scripts/create-signing-cert.sh" >&2
    codesign --force --sign - --entitlements "$ROOT/Resources/Quadro.entitlements" "$APP"
fi

echo "$APP"
