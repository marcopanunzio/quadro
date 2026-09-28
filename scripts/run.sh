#!/usr/bin/env bash
# Assembla e avvia l'app. Gli argomenti vanno all'app (es. scripts/run.sh --mock).
# L'app va avviata con `open`: lanciando il binario i permessi finirebbero al Terminale.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/bundle.sh" debug >/dev/null
pkill -x Quadro 2>/dev/null || true
open -n "$ROOT/build/Quadro.app" --args "$@"
