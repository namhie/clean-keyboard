#!/bin/sh
# Собирает Release и упаковывает в build/Clean-Keyboard.dmg (окно «перетащи в Программы»).
# Запуск из корня проекта: sh Scripts/make-dmg.sh
set -eu

APP="build/Build/Products/Release/Clean Keyboard.app"
STAGE="build/dmg"
DMG="build/Clean-Keyboard.dmg"

xcodegen generate
xcodebuild -project CleanKeyboard.xcodeproj -scheme CleanKeyboard -configuration Release \
    -derivedDataPath build build | grep -E "error:|BUILD" || true
[ -d "$APP" ] || { echo "Сборка не найдена: $APP" >&2; exit 1; }

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Clean Keyboard.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "Clean Keyboard" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"
echo "Готово: $DMG"
