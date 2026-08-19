#!/usr/bin/env bash
#
# Takes the App Store screenshots: six screens × twelve languages, framed and captioned.
#
#     scripts/shots.sh                # all twelve languages
#     scripts/shots.sh fr-FR ja       # only these listings, by App Store Connect code
#     scripts/shots.sh --frame-only   # re-frame what is already in build/shots/raw
#     scripts/shots.sh --review       # only the paywall, for App Store review
#
# Output: build/shots/raw/<store>/NN-screen.png   as the simulator saw it
#         build/shots/framed/<store>/NN-screen.png  what gets uploaded
#         build/shots/review/paywall.png         sent with each product, not published
#
# One build, twelve launches. The app is built for testing once and then relaunched per language
# with `-AppleLanguages`, which is the only way to get a screenshot of a *release-configured*
# binary in Hindi without twelve builds. It also means the screenshots are of the same bits that
# get submitted.
#
# The simulator is put into each language too, and resprung, which is what costs the run its twenty
# minutes. Launch arguments localize the app process and nothing else, so without it every shot
# carries an English status bar, and the Arabic ones a left-to-right one with Latin digits.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
BUILD="$ROOT/build"
RAW="$BUILD/shots/raw"
FRAMED="$BUILD/shots/framed"
DERIVED="$BUILD/shots/derived"
# One image, English, unframed: Apple asks for a picture of the purchase screen with every product
# and never publishes it. `scripts/iap.py` uploads it to all three.
REVIEW="$BUILD/shots/review"

# The 6.9-inch device the store requires, created by name so a rerun reuses it rather than
# accumulating simulators. iPhone 17 Pro Max renders 1320×2868, one of the two accepted sizes.
SIMULATOR="Dawnbreak 6.9"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"

# 9:41 in the status bar, expressed as the instant that reads 9:41 on this Mac's clock.
#
# The simulator takes the timezone of the host and `--time` takes an instant, so a hardcoded
# `09:41Z` puts 10:41 in the bar on a machine in Paris and 4:41 on one in New York. Computed instead
# of hardcoded so the screenshots come out the same wherever this runs. It also has to be exactly
# this spelling: `simctl` rejects `09:41:00Z`, `09:41:00+0000` and `9:41 AM` as "non-ISO".
CLOCK=$(python3 -c "
from datetime import datetime, timezone
print(datetime(2026, 1, 1, 9, 41).astimezone().astimezone(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.000Z'))
")

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mshots:\033[0m %s\n' "$*" >&2; exit 1; }

FRAME_ONLY=0
REVIEW_ONLY=0
WANTED=()
for argument in "$@"; do
  case "$argument" in
    --frame-only) FRAME_ONLY=1 ;;
    --review) REVIEW_ONLY=1 ;;
    -*) die "unknown option $argument" ;;
    *) WANTED+=("$argument") ;;
  esac
done

[[ $FRAME_ONLY -eq 1 && $REVIEW_ONLY -eq 1 ]] && die "--frame-only and --review do different jobs"
[[ $REVIEW_ONLY -eq 1 && ${#WANTED[@]} -gt 0 ]] && die "--review takes no languages: the review screenshot is English"

# ---------------------------------------------------------------------------
# The compositor, which also answers "which languages?" so this script holds
# no list of its own. Adding a thirteenth language is one row in Swift.
# ---------------------------------------------------------------------------

say "Building the compositor"
mkdir -p "$BUILD"
swiftc -O -swift-version 6 -parse-as-library \
  "$ROOT/scripts/frame-shots.swift" \
  "$ROOT/Sources/Contract/CaptureLocale.swift" \
  "$ROOT/Sources/Contract/CaptureLaunch.swift" \
  -o "$BUILD/frame-shots"

LOCALES=$("$BUILD/frame-shots" locales)

wanted() {
  [[ ${#WANTED[@]} -eq 0 ]] && return 0
  local candidate="$1" entry
  for entry in "${WANTED[@]}"; do [[ "$entry" == "$candidate" ]] && return 0; done
  return 1
}

if [[ ${#WANTED[@]} -gt 0 ]]; then
  while read -r store _; do
    printf '%s\n' "$store"
  done <<< "$LOCALES" > "$BUILD/.stores"
  for entry in "${WANTED[@]}"; do
    grep -qxF "$entry" "$BUILD/.stores" || die "$entry is not a language this app ships: $(tr '\n' ' ' < "$BUILD/.stores")"
  done
  rm -f "$BUILD/.stores"
fi

# ---------------------------------------------------------------------------
# The simulator, and the one build every capture runs on. Shared by the
# twelve-language run and by --review, which need the same device in the same
# state and differ only in what they photograph on it.
# ---------------------------------------------------------------------------

# Sets UDID and PREFERENCES, which everything below reads.
prepare_simulator() {
  command -v xcodegen >/dev/null || die "xcodegen is not installed: brew install xcodegen"

  say "Generating the project"
  xcodegen generate --quiet

  say "Creating $SIMULATOR if it does not exist"
  UDID=$(xcrun simctl list devices --json \
    | python3 -c "
import json, sys
devices = json.load(sys.stdin)['devices']
for runtime, entries in devices.items():
    for device in entries:
        if device['name'] == '$SIMULATOR':
            print(device['udid'])
            raise SystemExit
" || true)

  if [[ -z "$UDID" ]]; then
    RUNTIME=$(xcrun simctl list runtimes --json \
      | python3 -c "
import json, sys
runtimes = [r for r in json.load(sys.stdin)['runtimes'] if r['isAvailable'] and 'iOS' in r['name']]
runtimes.sort(key=lambda r: [int(part) for part in r['version'].split('.')])
print(runtimes[-1]['identifier'] if runtimes else '')
")
    [[ -n "$RUNTIME" ]] || die "no iOS runtime is installed"
    UDID=$(xcrun simctl create "$SIMULATOR" "$DEVICE_TYPE" "$RUNTIME")
    say "Created $SIMULATOR ($UDID)"
  fi

  say "Booting $UDID"
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b

  # Where the device keeps the preferences SpringBoard reads at launch. `simctl` has no command that
  # writes them on a shut-down device, so `use_language` writes the file directly. Resolved after the
  # first boot, because a freshly created device has no data directory until then.
  PREFERENCES="$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data/Library/Preferences"
  [[ -d "$PREFERENCES" ]] || die "$UDID booted without a preferences directory at $PREFERENCES"
}

build_runner() {
  # The `Screenshots` scheme, whose only test target is `DawnbreakUITests` and whose test
  # configuration is Release: the screenshots have to be of the binary that gets archived, and the
  # unit tests cannot be built against a Release app because `@testable import` needs
  # `-enable-testing`. See the comment on the scheme in project.yml.
  #
  # `ONLY_ACTIVE_ARCH=YES` because these bits run on one simulator on this Mac and are then thrown
  # away; building the x86_64 slice as well doubles the wait for nothing.
  say "Building the app and the UI test runner once"
  xcodebuild build-for-testing \
    -project Dawnbreak.xcodeproj \
    -scheme Screenshots \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DERIVED" \
    -quiet \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_ALLOWED=NO
}

# $1 an AppleLanguages value, $2 an AppleLocale value. Resprings the device into that language and
# reapplies the status bar, because a shutdown clears the overrides.
use_language() {
  # The status bar belongs to SpringBoard, not to the app, and `-AppleLanguages` on the app's
  # command line does not reach it. Without this the Arabic screenshots carry a left-to-right
  # status bar with Latin digits over a mirrored Arabic screen. So the *device* is put into the
  # language, which means a shutdown and a boot: the preference is read at launch and there is no
  # supported way to make a running SpringBoard read it again.
  #
  # `plutil` on the file rather than `defaults write`, and shut down rather than booted. The host's
  # `cfprefsd` caches any domain it is asked to write, including one that belongs to a simulator,
  # and hands the stale copy back on the next read while the device boots from what is on disk;
  # `simctl spawn defaults` is worse, because spawn needs a booted device and the device's own
  # `cfprefsd` then rewrites the file from its cache on the way down. Neither wrote Japanese.
  xcrun simctl shutdown "$UDID" 2>/dev/null || true
  plutil -replace AppleLanguages -json "[\"$1\"]" "$PREFERENCES/.GlobalPreferences.plist"
  plutil -replace AppleLocale -string "$2" "$PREFERENCES/.GlobalPreferences.plist"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b

  # 9:41 is the time in every iPhone screenshot Apple has ever published; full bars and a charged
  # battery because 43% and two bars read as someone's phone rather than as a product shot.
  # SpringBoard formats `$CLOCK` in its own language, which is what the respring above buys:
  # Japanese gets 9:41 on a 24-hour clock, English 9:41 AM, Arabic Arabic-Indic digits.
  xcrun simctl status_bar "$UDID" override \
    --time "$CLOCK" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
}

# Left in the language of whichever listing came last otherwise, which is a surprise the next
# person to open this simulator by hand does not deserve.
finish_simulator() {
  xcrun simctl status_bar "$UDID" clear
  xcrun simctl shutdown "$UDID" 2>/dev/null || true
  plutil -replace AppleLanguages -json '["en"]' "$PREFERENCES/.GlobalPreferences.plist"
  plutil -replace AppleLocale -string en_US "$PREFERENCES/.GlobalPreferences.plist"
}

# ---------------------------------------------------------------------------
# The review screenshot: one screen, one language, no frame
# ---------------------------------------------------------------------------

if [[ $REVIEW_ONLY -eq 1 ]]; then
  prepare_simulator

  say "Capturing the paywall for App Store review"
  rm -rf "$REVIEW"
  mkdir -p "$REVIEW"
  use_language en en_US

  # `DawnbreakTests` and not the UI tests, which is the whole reason this branch shares nothing with
  # the twelve-language run but the simulator.
  #
  # The paywall needs prices, prices need a StoreKit test session, and a session installs its
  # products for the bundle id of the process that creates one. A UI test runner is its own bundle
  # id, so the app under test finds nothing there and photographs "Prices are not loading"; a unit
  # test bundle is loaded into the app, so the session and the screen are the same process. See the
  # comment on `ReviewShotTests`, which also explains what that costs.
  #
  # The `Dawnbreak` scheme, therefore Debug, therefore its own derived data: the twelve-language run
  # builds the same targets in Release into `$DERIVED` and frames from whatever `Dawnbreak.app` it
  # finds there.
  #
  # Signed, unlike every other build here, and with entitlements the app does not otherwise ask for.
  # `storekitd` will not hold a StoreKit configuration for an app that is not a development install,
  # and what it reads is `get-task-allow`: without it `saveConfigurationData` is answered with
  # "com.aymbam.dawnbreak is not installed for development", the session is created without
  # complaint, no products arrive, and the paywall photographs "Prices are not loading". The
  # entitlement is in `Configuration/Dawnbreak-Debug.entitlements`, generated by xcodegen from the
  # `DawnbreakTests` target, and passed here rather than wired into the project so that no other
  # build can pick it up: a distribution profile does not authorise it, and an archive signed with it
  # fails. It applies to the widget as well, which is harmless and unavoidable, a command-line
  # setting reaching every target in the build. Debug signs itself ad hoc on a simulator, so none of
  # this costs a certificate or an account.
  env TEST_RUNNER_DAWNBREAK_REVIEW_SHOT="$REVIEW" \
    xcodebuild test \
      -project Dawnbreak.xcodeproj \
      -scheme Dawnbreak \
      -destination "platform=iOS Simulator,id=$UDID" \
      -derivedDataPath "$BUILD/shots/derived-review" \
      -only-testing:DawnbreakTests/ReviewShotTests \
      -quiet \
      ONLY_ACTIVE_ARCH=YES \
      CODE_SIGN_ENTITLEMENTS=Configuration/Dawnbreak-Debug.entitlements

  finish_simulator
  [[ -f "$REVIEW/paywall.png" ]] || die "the test passed but wrote no $REVIEW/paywall.png"
  say "Done. $REVIEW/paywall.png, uploaded to all three products by scripts/iap.py"
  exit 0
fi

# ---------------------------------------------------------------------------
# Capture
# ---------------------------------------------------------------------------

if [[ $FRAME_ONLY -eq 0 ]]; then
  prepare_simulator
  build_runner

  rm -rf "$RAW"
  mkdir -p "$RAW"

  # One xcodebuild invocation per language, rather than one run that loops inside the test. The
  # simulator has to be put into the language and resprung between languages, and only this side of
  # the process can do that, so the loop has to live here. `DAWNBREAK_SHOTS_ONLY` makes the other
  # eleven test methods skip; what that costs is a runner launch, and what it buys is a report that
  # names the language that failed and a rerun that retakes one language instead of twelve.
  FAILED=()
  while IFS=$'\t' read -r store language apple_locale; do
    wanted "$store" || continue
    say "Capturing $store ($language)"
    use_language "$language" "$apple_locale"

    # A failure here is not fatal to the run: eleven good languages plus a named twelfth is more
    # useful than an aborted script, and the summary at the end says which ones to retake.
    if ! env \
      TEST_RUNNER_DAWNBREAK_SHOTS="$RAW" \
      TEST_RUNNER_DAWNBREAK_SHOTS_ONLY="$store" \
      xcodebuild test-without-building \
        -project Dawnbreak.xcodeproj \
        -scheme Screenshots \
        -destination "platform=iOS Simulator,id=$UDID" \
        -derivedDataPath "$DERIVED" \
        -only-testing:DawnbreakUITests/ScreenshotTests \
        -quiet \
        CODE_SIGNING_ALLOWED=NO
    then
      printf '\033[1;33mshots:\033[0m %s failed to capture, continuing\n' "$store" >&2
      FAILED+=("$store")
      continue
    fi

    count=$(find "$RAW/$store" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')
    say "$store: $count screenshots"
  done <<< "$LOCALES"

  if [[ ${#FAILED[@]} -gt 0 ]]; then
    printf '\033[1;33mshots:\033[0m retake with: scripts/shots.sh %s\n' "${FAILED[*]}" >&2
  fi

  finish_simulator
fi

# ---------------------------------------------------------------------------
# Framing
# ---------------------------------------------------------------------------

APP=$(find "$DERIVED/Build/Products" -maxdepth 2 -name 'Dawnbreak.app' -type d | head -1)
[[ -n "$APP" ]] || die "no built Dawnbreak.app under $DERIVED — run without --frame-only first"

say "Framing from $(basename "$(dirname "$APP")")"
mkdir -p "$FRAMED"

if [[ ${#WANTED[@]} -gt 0 ]]; then
  "$BUILD/frame-shots" --raw "$RAW" --out "$FRAMED" --app "$APP" \
    --only "$(IFS=,; printf '%s' "${WANTED[*]}")"
else
  "$BUILD/frame-shots" --raw "$RAW" --out "$FRAMED" --app "$APP"
fi

say "Done. Upload from $FRAMED"
