#!/bin/zsh
# Build Daybook.app. Usage:
#   ./build.sh          build the app bundle into build/
#   ./build.sh test     run store tests only
#   ./build.sh install  build and copy to /Applications
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Daybook.app
MODE="${1:-build}"

# The installed CLT (26.3) ships a stale usr/include/swift/module.modulemap that
# duplicates bridging.modulemap and breaks every Foundation build. The overlay
# masks the stale file without touching system files. See build/overlay.yaml.
OVERLAY=(-vfsoverlay build/overlay.yaml)

make_overlay() {
  printf '// stale duplicate of bridging.modulemap, masked via VFS overlay\n' > build/empty.modulemap
  cat > build/overlay.yaml <<EOF
{
  "version": 0,
  "case-sensitive": "false",
  "roots": [
    {
      "name": "/Library/Developer/CommandLineTools/usr/include/swift",
      "type": "directory",
      "contents": [
        {
          "name": "module.modulemap",
          "type": "file",
          "external-contents": "$PWD/build/empty.modulemap"
        }
      ]
    }
  ]
}
EOF
}

run_tests() {
  echo "== Running store tests =="
  cp tools/store_tests.swift build/main.swift
  swiftc "${OVERLAY[@]}" -o build/store_tests Sources/Models.swift Sources/Crypto.swift build/main.swift
  ./build/store_tests
}

build_app() {
  echo "== Compiling =="
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
  swiftc "${OVERLAY[@]}" -O -parse-as-library \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/Daybook"

  cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Daybook</string>
    <key>CFBundleIdentifier</key><string>com.spencermccauley.daybook</string>
    <key>CFBundleName</key><string>Daybook</string>
    <key>CFBundleDisplayName</key><string>Daybook</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

  echo "== Icon =="
  if [ ! -f build/icon_1024.png ]; then
    swift "${OVERLAY[@]}" tools/make_icon.swift build/icon_1024.png
  fi
  ICONSET=build/AppIcon.iconset
  rm -rf "$ICONSET" && mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z $s $s build/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z $d $d build/icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

  echo "== Signing (ad hoc) =="
  codesign --force --deep -s - "$APP"
  echo "Built $APP"
}

mkdir -p build
make_overlay

case "$MODE" in
  test) run_tests ;;
  build) run_tests && build_app ;;
  install)
    run_tests && build_app
    echo "== Installing =="
    rm -rf /Applications/Daybook.app
    ditto "$APP" /Applications/Daybook.app
    echo "Installed to /Applications/Daybook.app"
    ;;
  *) echo "Unknown mode: $MODE" && exit 1 ;;
esac
