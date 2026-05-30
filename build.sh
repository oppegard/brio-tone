#!/bin/bash
# Builds BrioTone.app — a menu-bar app to control the MX Brio sensor.
set -euo pipefail
cd "$(dirname "$0")"

APP="dist/BrioTone.app"

# Bootstrap the UVC control helper (uvc-util, MIT © Jeffrey Frey) from source if
# it isn't present. We don't commit the binary — it's built locally on demand.
if [ ! -x "Resources/uvc-util" ]; then
  echo "▸ Compilando uvc-util (dependencia UVC, MIT)…"
  mkdir -p Resources
  TMP="$(mktemp -d)"
  git clone --depth 1 https://github.com/jtfrey/uvc-util.git "$TMP" >/dev/null 2>&1
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
