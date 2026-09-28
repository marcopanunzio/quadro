#!/usr/bin/env bash
# Compila Quadro in release e lo installa (o aggiorna) in /Applications.
# Uso: scripts/install.sh [cartella di destinazione, default /Applications]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-/Applications}"
APP="$DEST/Quadro.app"

"$ROOT/scripts/bundle.sh" release >/dev/null

was_running=false
if pgrep -x Quadro >/dev/null; then
    was_running=true
    osascript -e 'tell application id "com.mpanunzio.Quadro" to quit' >/dev/null 2>&1 || true
    # Aspetta la chiusura: l'app esegue le eliminazioni in sospeso prima di uscire.
    for _ in $(seq 1 50); do pgrep -x Quadro >/dev/null || break; sleep 0.2; done
fi

rm -rf "$APP"
ditto "$ROOT/build/Quadro.app" "$APP"
echo "Installato: $APP ($(git -C "$ROOT" describe --always --dirty))"

if $was_running; then
    open "$APP"
fi
