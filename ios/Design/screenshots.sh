#!/bin/zsh
# App Store のスクリーンショットを撮り、見出しの帯を付ける
#
# Debug でシミュレーター用にビルドし、2台のシミュレーターで、日本語と英語の6枚ずつを撮る。
# 演出の見本（-demo）に、見本の記録（-seed）を入れて開く。端末に保存された記録には触れない。
#
#     cd ios && Design/screenshots.sh
#
# できあがりは Design/Screenshots/{ja,en}/{6.9,6.3}/。撮ったままの画像は Design/Screenshots/raw/。
# 決まり事と見出しの文言は docs/devops/app-store#screenshots。
set -euo pipefail

cd "${0:A:h}/.."
OUT=Design/Screenshots
BUILD=$OUT/build
BUNDLE=com.yat-tat-ta

# App Store Connect の枠とシミュレーター
typeset -A DEVICES=( 6.9 "iPhone 18 Pro Max" 6.3 "iPhone 18 Pro" )
typeset -A LOCALES=( ja ja_JP en en_US )

# 番号、場面、起動引数、撮るまでの秒数。秒数は起動してから。演出の途中を撮るので、ずれたらここを直す
SCENES=(
  "1|squad|-demo squad|6.5"
  "2|fever|-demo fever|3.0"
  "3|kakutei|-demo kakutei|4.0"
  "4|home|-demo home|3.0"
  "5|history|-demo history|4.0"
  "6|splash|-demo splash -splashAt 1.1|3.0"
)

echo "ビルドする"
xcodegen generate -q
xcodebuild build -project YatTatTa.xcodeproj -scheme YatTatTa -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$BUILD" \
  -clonedSourcePackagesDirPath ~/Library/Developer/Xcode/DerivedData/spm-shared -quiet
APP=$BUILD/Build/Products/Debug-iphonesimulator/YatTatTa.app

rm -rf "$OUT/raw" "$OUT/ja" "$OUT/en"
for size in ${(k)DEVICES}; do
  name=${DEVICES[$size]}
  udid=$(xcrun simctl list devices available | grep -F "    $name (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  if [[ -z $udid ]]; then
    echo "error: シミュレーター「$name」がありません。Xcode の Devices and Simulators で足してください"
    exit 1
  fi
  echo "$name（$size インチ）で撮る"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl ui "$udid" appearance light
  xcrun simctl status_bar "$udid" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
  xcrun simctl install "$udid" "$APP"
  # 起動したての1回めは描くのが遅れるので、撮る前に1回開いておく
  xcrun simctl launch "$udid" $BUNDLE -demo home -seed >/dev/null
  sleep 6
  for lang in ${(k)LOCALES}; do
    mkdir -p "$OUT/raw/$lang/$size"
    for scene in $SCENES; do
      IFS='|' read -r no key launchArgs wait <<< "$scene"
      xcrun simctl terminate "$udid" $BUNDLE 2>/dev/null || true
      xcrun simctl launch "$udid" $BUNDLE ${=launchArgs} -seed -AppleLanguages "($lang)" -AppleLocale ${LOCALES[$lang]} >/dev/null
      sleep $wait
      xcrun simctl io "$udid" screenshot --type=png "$OUT/raw/$lang/$size/$no-$key.png" >/dev/null 2>&1
      echo "  $lang $no-$key"
    done
  done
  xcrun simctl terminate "$udid" $BUNDLE 2>/dev/null || true
  xcrun simctl status_bar "$udid" clear
done

echo "見出しの帯を付ける"
swift Design/compose_screenshots.swift "$OUT/raw" "$OUT" >/dev/null
echo "できた: $OUT/{ja,en}/{6.9,6.3}/"
