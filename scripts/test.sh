#!/usr/bin/env bash
# swift test con i soli Command Line Tools: swift-testing sta in un percorso che SwiftPM non cerca da solo,
# e il modulo _Testing_Foundation dei CLT è incompleto, quindi si disattivano i cross-import overlay.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FW="$(xcode-select -p)/Library/Developer/Frameworks"

swift test --package-path "$ROOT" \
    -Xswiftc -F -Xswiftc "$FW" \
    -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
    -Xlinker -F -Xlinker "$FW" \
    -Xlinker -rpath -Xlinker "$FW" \
    "$@"
