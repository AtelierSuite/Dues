#!/bin/zsh
# Captures raw App Store screenshots into Raw/iPhone/<language>/.
# Usage: ./capture.sh [languages...]           (defaults to en ja)
#        ./capture.sh widgets [languages...]   (the Home Screen widgets, by hand)
#
# The app is launched in demo mode on each screen through the -ScreenshotScreen
# launch argument. Run compose.swift afterwards to frame the captures.
#
# The widgets can't be placed on the Home Screen from a script, so `widgets` seeds
# the demo receipts into the store on disk, opens the simulator, and waits for the
# widgets to be arranged before capturing 01-widgets.
set -e

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h:h}
BUNDLE_ID=com.tsubuzaki.Meloan
DERIVED_DATA=/tmp/dues-screenshots-dd
DEVICE_TYPE=com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max
RUNTIME=com.apple.CoreSimulator.SimRuntime.iOS-27-0
MODE=screens
if [[ $1 == widgets ]]; then
  MODE=widgets
  shift
fi
LANGUAGES=($@)
(( $# )) || LANGUAGES=(en ja)
SCREENS=(
  02-receipts:receipts
  03-receipt:receipt
  04-pdf:pdf
  05-iou:iou
  06-search-people:search-people
  06-search-items:search-items
  07-more:more
)

# MARK: - Simulator

simulator() {
  local name="Dues Screenshots iPhone" udid
  udid=$(xcrun simctl list devices available | grep "$name (" | head -1 | grep -oE '[0-9A-F-]{36}' || true)
  if [[ -z $udid ]]; then
    udid=$(xcrun simctl create "$name" $DEVICE_TYPE $RUNTIME)
  fi
  echo $udid
}

# The language is set on the whole simulator, which is restarted to pick it up.
# The preferences are edited while it is shut down: a `defaults write` through
# simctl spawn does not survive the restart.
boot() {
  local locale=$([[ $2 == ja ]] && echo ja_JP || echo en_US)
  local preferences=~/Library/Developer/CoreSimulator/Devices/$1/data/Library/Preferences/.GlobalPreferences.plist
  # The first boot is what creates the preferences.
  xcrun simctl boot $1 2>/dev/null || true
  xcrun simctl bootstatus $1 -b >/dev/null
  xcrun simctl shutdown $1
  plutil -replace AppleLanguages -json "[\"$2\"]" "$preferences"
  plutil -replace AppleLocale -string $locale "$preferences"
  xcrun simctl boot $1
  xcrun simctl bootstatus $1 -b >/dev/null
  xcrun simctl ui $1 appearance dark
  xcrun simctl status_bar $1 override --time 9:41 \
    --batteryState discharging --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName ""
}

# MARK: - Build

xcodebuild build -project "$PROJECT_DIR/Meloan.xcodeproj" -scheme Meloan -configuration Debug \
  -destination "generic/platform=iOS Simulator" -derivedDataPath $DERIVED_DATA -quiet
APP=$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Meloan.app

# MARK: - Capture

# The first launch after a fresh install now and then fails to start the app, so a
# failed launch is given one more go.
launch() {
  xcrun simctl launch --terminate-running-process $UDID $BUNDLE_ID -ScreenshotScreen $1 >/dev/null ||
    { sleep 3; xcrun simctl launch --terminate-running-process $UDID $BUNDLE_ID -ScreenshotScreen $1 >/dev/null; }
}

UDID=$(simulator)

for language in $LANGUAGES; do
  raw_dir="$SCRIPT_DIR/Raw/iPhone/$language"
  mkdir -p "$raw_dir"
  boot $UDID $language

  # A fresh install, so nothing is left over from an earlier run.
  xcrun simctl uninstall $UDID $BUNDLE_ID 2>/dev/null || true
  xcrun simctl install $UDID $APP

  if [[ $MODE == widgets ]]; then
    launch widgets
    open -a Simulator --args -CurrentDeviceUDID $UDID
    echo "Add the Dues widgets to the Home Screen of the simulator and pick a demo"
    echo "receipt for each, then press Return to capture 01-widgets ($language)."
    read
    xcrun simctl io $UDID screenshot "$raw_dir/01-widgets.png" >/dev/null 2>&1
  else
    for screen in $SCREENS; do
      launch ${screen#*:}
      # Let the demo data load and any push or sheet finish animating in.
      sleep 5
      xcrun simctl io $UDID screenshot "$raw_dir/${screen%%:*}.png" >/dev/null 2>&1
    done
    xcrun simctl terminate $UDID $BUNDLE_ID
  fi
  echo "captured iPhone/$language"
done
