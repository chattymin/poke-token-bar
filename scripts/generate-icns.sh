#!/bin/bash
# generate-icon.swift 로 멀티사이즈 네이티브 렌더 → assets/AppIcon.icns 생성.
# 각 사이즈를 1024 다운스케일이 아니라 직접 렌더해 작은 크기(16/32px)에서 T 가독성을 유지한다.
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"

gen() { swift scripts/generate-icon.swift "$ICONSET/$1" "$2" >/dev/null; }
gen icon_16x16.png        16
gen icon_16x16@2x.png     32
gen icon_32x32.png        32
gen icon_32x32@2x.png     64
gen icon_128x128.png     128
gen icon_128x128@2x.png  256
gen icon_256x256.png     256
gen icon_256x256@2x.png  512
gen icon_512x512.png     512
gen icon_512x512@2x.png 1024

iconutil -c icns "$ICONSET" -o assets/AppIcon.icns
swift scripts/generate-icon.swift assets/icon_1024.png 1024 >/dev/null
rm -rf "$ICONSET"
echo "done: assets/AppIcon.icns + assets/icon_1024.png"
