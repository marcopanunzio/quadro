#!/usr/bin/env bash
# Compila e assembla build/PersonalDashboard.app, poi lo firma.
# Uso: scripts/bundle.sh [debug|release]
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/PersonalDashboard.app"
IDENTITY="${SIGN_IDENTITY:-Personal Dashboard Dev}"

swift build -c "$CONFIG" --product PersonalDashboard --package-path "$ROOT"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path --package-path "$ROOT")"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/PersonalDashboard" "$APP/Contents/MacOS/"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/"

if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
    codesign --force --sign "$IDENTITY" --entitlements "$ROOT/Resources/PersonalDashboard.entitlements" "$APP"
else
    echo "attenzione: identità \"$IDENTITY\" non trovata, uso firma ad-hoc." >&2
    echo "  macOS potrebbe richiedere di nuovo i permessi a ogni build: vedi scripts/create-signing-cert.sh" >&2
    codesign --force --sign - --entitlements "$ROOT/Resources/PersonalDashboard.entitlements" "$APP"
fi

echo "$APP"
