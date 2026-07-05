#!/bin/zsh
# MenuCal: release 빌드 → .app 번들 조립 → ad-hoc 코드사인 → /Applications 설치 → 재실행
set -euo pipefail
cd "$(dirname "$0")"

NAME="MenuCal"
BUNDLE_ID="com.bk.MenuCal"
DEST="/Applications"
APP="build/$NAME.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$NAME" "$APP/Contents/MacOS/$NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>다가오는 이벤트(생일·기념일 등)를 달력과 메뉴바에 표시하기 위해 캘린더 접근이 필요합니다.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"

# 실행 중이면 종료 후 교체 (ditto: 서명 보존 복사)
pkill -x "$NAME" 2>/dev/null || true
sleep 0.5
rm -rf "$DEST/$NAME.app"
ditto "$APP" "$DEST/$NAME.app"
open "$DEST/$NAME.app"
echo "✅ $DEST/$NAME.app 설치 + 실행 완료"
