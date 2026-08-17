#!/bin/bash
# Builds BrioTone.app — a menu-bar app to control the MX Brio sensor.
set -euo pipefail
cd "$(dirname "$0")"

APP="dist/BrioTone.app"
UVC_UTIL_SHA="8110da7025c95eea3096a7181af9a46c0cc7ac37"

# Bootstrap the UVC control helper (uvc-util, MIT © Jeffrey Frey) from pinned
# source if the bundled binary isn't present.
if [ ! -x "Resources/uvc-util" ]; then
  echo "▸ Compilando uvc-util (dependencia UVC, MIT)…"
  mkdir -p Resources
  TMP="$(mktemp -d)"
  git clone --no-checkout https://github.com/jtfrey/uvc-util.git "$TMP" >/dev/null 2>&1
  git -C "$TMP" checkout --detach "$UVC_UTIL_SHA" >/dev/null 2>&1
  clang -O2 -o "Resources/uvc-util" "$TMP"/src/*.m \
    -framework Foundation -framework IOKit -framework CoreFoundation
  rm -rf "$TMP"
fi

echo "▸ Compilando…"
swift build -c release

echo "▸ Ensamblando $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp ".build/release/BrioTone" "$APP/Contents/MacOS/BrioTone"
cp "Info.plist"             "$APP/Contents/Info.plist"
cp "Resources/uvc-util"     "$APP/Contents/Resources/uvc-util"
chmod +x "$APP/Contents/Resources/uvc-util" "$APP/Contents/MacOS/BrioTone"

echo "▸ Firmando (ad-hoc)…"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "✓ Listo: $APP"
