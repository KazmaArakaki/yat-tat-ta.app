#!/bin/zsh
# SNS の縦動画を1本作る
#
# Debug でシミュレーター用にビルドし、演出の見本の reel（-demo reel）を見本の記録（-seed）で流して画面を録る。
# シミュレーターの録画には音が入らないので、アプリが鳴らした音をファイルに書き（-recordAudio）、あとで重ねる。
# 上の帯に場面ごとの文字を出し、終わりにアプリの名前を付けて、1080 × 1920 の縦長にする（Design/compose_reel.py）。
# 端末に保存された記録には触れない。
#
#     cd ios && Design/reel.sh [ja|en] [sns|lp]
#
# sns（既定）は SNS の縦動画で、叩き切ったところまで。lp は公開ページの動画で、そのあとの共有の誘いまで録る。
# できあがりは Design/Reels/{sns なら reel、lp なら lp}-{言語}.mp4。帯の文字は compose_reel.py の CAPTIONS で変える。
# 決まり事は docs/devops/sns-marketing、型は docs/sessions/20261007-1727-sns-marketing/x-video.html。
set -euo pipefail

cd "${0:A:h}/.."
OUT=Design/Reels
BUILD=Design/Screenshots/build
BUNDLE=com.yat-tat-ta
DEVICE="iPhone 18 Pro"
LANG_CODE=${1:-ja}
KIND=${2:-sns}
case $LANG_CODE in
  ja) LOCALE=ja_JP ;;
  en) LOCALE=en_US ;;
  *) echo "error: 言語は ja か en"; exit 1 ;;
esac
case $KIND in
  sns) NAME=reel; EXTRA=() ;;
  lp) NAME=lp; EXTRA=(-reelShare) ;;
  *) echo "error: 種類は sns か lp"; exit 1 ;;
esac
echo "ビルドする"
xcodegen generate -q
xcodebuild build -project YatTatTa.xcodeproj -scheme YatTatTa -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$BUILD" \
  -clonedSourcePackagesDirPath ~/Library/Developer/Xcode/DerivedData/spm-shared -quiet
APP=$BUILD/Build/Products/Debug-iphonesimulator/YatTatTa.app

udid=$(xcrun simctl list devices available | grep -F "    $DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
if [[ -z $udid ]]; then
  echo "error: シミュレーター「$DEVICE」がありません。Xcode の Devices and Simulators で足してください"
  exit 1
fi
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl ui "$udid" appearance light
xcrun simctl status_bar "$udid" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl install "$udid" "$APP"
# 起動したての1回めは描くのが遅れるので、録る前に1回開いておく
xcrun simctl terminate "$udid" $BUNDLE 2>/dev/null || true
xcrun simctl launch "$udid" $BUNDLE -demo home -seed >/dev/null
sleep 5
xcrun simctl terminate "$udid" $BUNDLE 2>/dev/null || true

DATA=$(xcrun simctl get_app_container "$udid" $BUNDLE data)
rm -f "$DATA/Documents/reel.json" "$DATA/Documents/reel.caf"
WORK=$(mktemp -d)
mkdir -p "$OUT"

echo "録る"
xcrun simctl io "$udid" recordVideo --codec=h264 --mask=black --force "$WORK/screen.mov" 2> "$WORK/record.log" &
recorder=$!
until grep -q "Recording started" "$WORK/record.log" 2>/dev/null; do sleep 0.05; done
recordStart=$(python3 -c 'import time; print(time.time())')
xcrun simctl launch "$udid" $BUNDLE -demo reel -seed -recordAudio "${EXTRA[@]}" \
  -AppleLanguages "($LANG_CODE)" -AppleLocale $LOCALE >/dev/null
# アプリが音を書き終えるまで待つ（40秒で諦める）
for i in {1..400}; do [[ -f "$DATA/Documents/reel.json" ]] && break; sleep 0.1; done
sleep 0.5
kill -INT $recorder
wait $recorder 2>/dev/null || true
xcrun simctl terminate "$udid" $BUNDLE 2>/dev/null || true
xcrun simctl status_bar "$udid" clear
if [[ ! -f "$DATA/Documents/reel.json" ]]; then
  echo "error: アプリが reel を書き終えませんでした"
  exit 1
fi

echo "帯の文字と終わりの画面を付ける"
cp "$DATA/Documents/reel.caf" "$DATA/Documents/reel.json" "$WORK/"
python3 Design/compose_reel.py "$WORK" "$recordStart" "$OUT/$NAME-$LANG_CODE.mp4" "$LANG_CODE" "$KIND"
rm -rf "$WORK"
echo "できた: $OUT/$NAME-$LANG_CODE.mp4"
