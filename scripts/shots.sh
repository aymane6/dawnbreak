#!/usr/bin/env bash
#
# Takes the App Store screenshots: six screens × twelve languages, framed and captioned.
#
#     scripts/shots.sh                # all twelve languages
#     scripts/shots.sh fr-FR ja       # only these listings, by App Store Connect code
#     scripts/shots.sh --frame-only   # re-frame what is already in build/shots/raw
#
# Output: build/shots/raw/<store>/NN-screen.png   as the simulator saw it
#         build/shots/framed/<store>/NN-screen.png  what gets uploaded
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
WANTED=()
for argument in "$@"; do
  case "$argument" in
    --frame-only) FRAME_ONLY=1 ;;
    -*) die "unknown option $argument" ;;
    *) WANTED+=("$argument") ;;
  esac
done

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
# The simulator, and the one build every capture runs on.
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

  # A device caught in `Shutting Down` refuses to boot with CoreSimulator error 405, and the boot
  # below is the one command in this script that is not allowed to fail, so wait for a settled state
  # first. Costs nothing when the device is already down or already up.
  for _ in $(seq 90); do
    state=$(xcrun simctl list devices | grep "$UDID" | sed -E 's/.*\(([^()]*)\)[[:space:]]*$/\1/')
    [[ "$state" == "Shutdown" || "$state" == "Booted" ]] && break
    sleep 1
  done

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

# Waits until the device is really down, because `simctl shutdown` does not.
#
# It returns as soon as the request is accepted, and on a loaded machine the device stays in
# `Shutting Down` for seconds afterwards. Booting inside that window looks like it works: `bootstatus`
# printed `Finished` with `Elapsed=00:00` on 2026-09-03, and the next command died with CoreSimulator
# error 405, "Unable to lookup in current state: Shutting Down", losing the run. So read the state
# rather than trusting the exit code.
wait_until_shutdown() {
  for _ in $(seq 90); do
    state=$(xcrun simctl list devices | grep "$UDID" | sed -E 's/.*\(([^()]*)\)[[:space:]]*$/\1/')
    [[ "$state" == "Shutdown" ]] && return 0
    sleep 1
  done

  # A device that will not go down has stopped answering, and on 2026-09-03 that cost a whole run:
  # `simctl status_bar clear` hung eleven minutes on a device sitting in `Booted` at 0.29 s of CPU,
  # while the test runner for the same device refused to launch. Killing that one device's
  # `launchd_sim` takes it down without touching CoreSimulator, which every other simulator on this
  # shared Mac depends on. Matched on the device directory so no other device can be hit.
  printf '\033[1;33mshots:\033[0m the simulator is stuck in %s, forcing it down\n' "$state" >&2
  pkill -f "Devices/$UDID/data/var/run/launchd_bootstrap.plist" || true
  for _ in $(seq 30); do
    state=$(xcrun simctl list devices | grep "$UDID" | sed -E 's/.*\(([^()]*)\)[[:space:]]*$/\1/')
    [[ "$state" == "Shutdown" ]] && return 0
    sleep 1
  done
  die "the simulator is still $state after being forced down"
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
  wait_until_shutdown
  plutil -replace AppleLanguages -json "[\"$1\"]" "$PREFERENCES/.GlobalPreferences.plist"
  plutil -replace AppleLocale -string "$2" "$PREFERENCES/.GlobalPreferences.plist"
  # Nothing in here is fatal to the run. `set -e` plus a device that has gone deaf used to abort all
  # twelve languages over one of them; the watchdog kills a hung `simctl` and the locale's own
  # `xcodebuild` then fails, which the capture loop tolerates and the retake pass fixes.
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b || true

  # 9:41 is the time in every iPhone screenshot Apple has ever published; full bars and a charged
  # battery because 43% and two bars read as someone's phone rather than as a product shot.
  # SpringBoard formats `$CLOCK` in its own language, which is what the respring above buys:
  # Japanese gets 9:41 on a 24-hour clock, English 9:41 AM, Arabic Arabic-Indic digits.
  xcrun simctl status_bar "$UDID" override \
    --time "$CLOCK" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 || true
}

# Left in the language of whichever listing came last otherwise, which is a surprise the next
# person to open this simulator by hand does not deserve.
finish_simulator() {
  # Every line tolerant of failure: this is tidying, and the seventy-two images are already on disk
  # by the time it runs. `status_bar clear` is the specific command that hung eleven minutes on a deaf
  # device on 2026-09-03, and with `set -e` that hang was between the capture and the framing.
  xcrun simctl status_bar "$UDID" clear || true
  xcrun simctl shutdown "$UDID" 2>/dev/null || true
  plutil -replace AppleLanguages -json '["en"]' "$PREFERENCES/.GlobalPreferences.plist" || true
  plutil -replace AppleLocale -string en_US "$PREFERENCES/.GlobalPreferences.plist" || true
}

# ---------------------------------------------------------------------------
# Capture
# ---------------------------------------------------------------------------

if [[ $FRAME_ONLY -eq 0 ]]; then
  prepare_simulator
  build_runner

  # Only the languages this run is going to retake. `rm -rf "$RAW"` used to be unconditional, which
  # made the retake this script itself recommends destroy the rest of the run: on 2026-09-03,
  # `scripts/shots.sh en-US de-DE`, copied from this script's own "retake with:" line, deleted the ten
  # languages the sweep had just spent forty-five minutes capturing.
  if [[ ${#WANTED[@]} -gt 0 ]]; then
    for store in "${WANTED[@]}"; do rm -rf "$RAW/$store"; done
  else
    rm -rf "$RAW"
  fi
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
