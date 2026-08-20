#!/usr/bin/env bash
#
# Opens an .xcarchive and checks the things that only exist once the compiler has run.
#
#     scripts/verify-archive.sh                          # build/Dawnbreak.xcarchive
#     scripts/verify-archive.sh path/to/Some.xcarchive   # any archive
#     scripts/verify-archive.sh --unsigned               # an archive built with no identity
#
# `scripts/asc-preflight.py` reads the sources: it can tell you the privacy manifest is in the repo
# and listed in the widget's target. Only the archive can tell you it was actually copied into both
# bundles, that the app and its extension ended up with the same build number, that twelve .lproj
# folders came out of the string catalogue, and that no simulator slice is riding along. Those are
# also the failures that arrive as an ITMS email an hour after the upload instead of as an error.
#
# Run by scripts/release.sh between the archive and the upload, and safe to run on its own against
# any archive Xcode has ever produced, including one built by the Organizer.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

# `--unsigned` is for the archive you can build with no Apple credentials at all
# (`CODE_SIGNING_ALLOWED=NO`), which is the only end-to-end proof available on a machine with no
# distribution certificate. Everything about the bundle's contents is still checked; the three
# checks that read a signature are skipped and say so, rather than passing on a technicality.
SIGNED=1
ARCHIVE=""
for argument in "$@"; do
  case "$argument" in
    --unsigned) SIGNED=0 ;;
    -*) printf '\033[1;31mverify-archive:\033[0m unknown option %s\n' "$argument" >&2; exit 1 ;;
    *) ARCHIVE="$argument" ;;
  esac
done
ARCHIVE="${ARCHIVE:-$ROOT/build/Dawnbreak.xcarchive}"

APP_BUNDLE_ID="com.aymbam.dawnbreak"
WIDGET_BUNDLE_ID="com.aymbam.dawnbreak.widget"
APP_GROUP="group.com.aymbam.dawnbreak"
TEAM_ID="2Y97DK7UM4"
# The twelve the app claims. Read from the contract rather than repeated, for the same reason
# everything else in this project reads it: a thirteenth language should be one row in one file.
LANGUAGE_COUNT=$(grep -c 'static let \w* = CaptureLocale(' "$ROOT/Sources/Contract/CaptureLocale.swift")

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
pass() { printf '  \033[1;32m✓\033[0m %-52s %s\n' "$1" "${2:-}"; }
skip() { printf '  \033[1;33m-\033[0m %-52s %s\n' "$1" "${2:-}"; }
FAILURES=0
fail() { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAILURES=$((FAILURES + 1)); }

[[ -d "$ARCHIVE" ]] || { printf '\033[1;31mverify-archive:\033[0m no archive at %s\n' "$ARCHIVE" >&2; exit 1; }

# `plutil -extract … raw` prints scalars unquoted and exits non-zero on a missing key, which is the
# behaviour this wants: an absent key becomes the literal <missing> and fails a comparison.
value() { /usr/bin/plutil -extract "$1" raw -o - "$2" 2>/dev/null || printf '<missing>'; }
# An array's length. PlistBuddy wraps its output in `Array {` … `}`, hence the trimmed first and
# last lines.
count() { /usr/libexec/PlistBuddy -c "Print :$1" "$2" 2>/dev/null | sed '1d;$d' | grep -c . || true; }
expect() {
  local label="$1" found="$2" wanted="$3"
  if [[ "$found" == "$wanted" ]]; then pass "$label" "$found"; else fail "$label: $found, expected $wanted"; fi
}

say "Archive: ${ARCHIVE/#$ROOT\//}"

# ---------------------------------------------------------------------------
# What the archive says it is
# ---------------------------------------------------------------------------

ARCHIVE_PLIST="$ARCHIVE/Info.plist"
RELATIVE_APP=$(value "ApplicationProperties.ApplicationPath" "$ARCHIVE_PLIST")
APP="$ARCHIVE/Products/$RELATIVE_APP"
[[ -d "$APP" ]] || { fail "the archive names $RELATIVE_APP, which is not in Products/"; exit 1; }

APP_PLIST="$APP/Info.plist"
VERSION=$(value CFBundleShortVersionString "$APP_PLIST")
BUILD=$(value CFBundleVersion "$APP_PLIST")

# A `$(MARKETING_VERSION)` that reached the built bundle means the plist was copied rather than
# processed, and App Store Connect reads it literally.
if [[ "$VERSION" == *'$('* || "$BUILD" == *'$('* ]]; then
  fail "the version was not substituted: $VERSION ($BUILD)"
else
  pass "version" "$VERSION ($BUILD)"
fi

expect "app bundle id"          "$(value CFBundleIdentifier "$APP_PLIST")" "$APP_BUNDLE_ID"
expect "encryption declaration" "$(value ITSAppUsesNonExemptEncryption "$APP_PLIST")" "false"
expect "Live Activities"        "$(value NSSupportsLiveActivities "$APP_PLIST")" "true"
expect "app languages"          "$(count CFBundleLocalizations "$APP_PLIST")" "$LANGUAGE_COUNT"

for key in NSAlarmKitUsageDescription NSCameraUsageDescription NSMotionUsageDescription; do
  if [[ "$(value "$key" "$APP_PLIST")" == "<missing>" ]]; then
    fail "$key is not in the built Info.plist"
  fi
done
pass "purpose strings" "3 present"

# ---------------------------------------------------------------------------
# What the compiler produced
# ---------------------------------------------------------------------------

# The String Catalogue compiles to one .lproj per language. If it did not compile, every label on
# every screen renders as its own key, and nothing about the build fails.
APP_LPROJ=$(find "$APP" -maxdepth 1 -name "*.lproj" | wc -l | tr -d ' ')
expect "compiled string tables" "$APP_LPROJ" "$LANGUAGE_COUNT"

# And the source catalogue must *not* be in the bundle: a copied .xcstrings is 200 KB of JSON that
# does nothing, and it means the file was treated as a resource instead of compiled.
if find "$APP" -name "*.xcstrings" | grep -q .; then
  fail "an uncompiled .xcstrings was copied into the bundle"
else
  pass "no uncompiled catalogues" "compiled, not copied"
fi

if [[ -f "$APP/Assets.car" ]]; then
  pass "asset catalogue" "Assets.car"
else
  fail "Assets.car is missing, so the icon and the palette did not compile"
fi

# iOS 17 onwards: the manifest has to be in each bundle that calls a required-reason API, and both
# of these read UserDefaults. Its absence is silent until the ITMS-91053 email.
for bundle in "$APP" "$APP/PlugIns/DawnbreakWidget.appex"; do
  name=$(basename "$bundle")
  if [[ -f "$bundle/PrivacyInfo.xcprivacy" ]]; then
    pass "privacy manifest in $name" "present"
  else
    fail "$name has no PrivacyInfo.xcprivacy"
  fi
done

# ---------------------------------------------------------------------------
# The extension
# ---------------------------------------------------------------------------

WIDGET="$APP/PlugIns/DawnbreakWidget.appex"
if [[ -d "$WIDGET" ]]; then
  WIDGET_PLIST="$WIDGET/Info.plist"
  expect "widget bundle id" "$(value CFBundleIdentifier "$WIDGET_PLIST")" "$WIDGET_BUNDLE_ID"
  # The upload is rejected outright when these disagree, and they disagree the moment somebody sets
  # a version on one target by hand.
  expect "widget build number" "$(value CFBundleVersion "$WIDGET_PLIST")" "$BUILD"
  expect "widget version"      "$(value CFBundleShortVersionString "$WIDGET_PLIST")" "$VERSION"
  expect "widget languages"    "$(count CFBundleLocalizations "$WIDGET_PLIST")" "$LANGUAGE_COUNT"
  WIDGET_LPROJ=$(find "$WIDGET" -maxdepth 1 -name "*.lproj" | wc -l | tr -d ' ')
  expect "widget string tables" "$WIDGET_LPROJ" "$LANGUAGE_COUNT"
else
  fail "PlugIns/DawnbreakWidget.appex is missing: the Live Activity would never draw"
fi

# ---------------------------------------------------------------------------
# Signing and slices
# ---------------------------------------------------------------------------

# A simulator slice in an uploaded binary is an immediate rejection, and it is what you get from
# archiving with the wrong destination.
ARCHS=$(/usr/bin/lipo -archs "$APP/$(value CFBundleExecutable "$APP_PLIST")" 2>/dev/null || echo "unreadable")
expect "architectures" "$ARCHS" "arm64"

if [[ "$SIGNED" -eq 0 ]]; then
  skip "code signature"     "not checked (--unsigned)"
  skip "app group entitlement" "not checked (--unsigned)"
  skip "team"               "not checked (--unsigned)"
  skip "not debuggable"     "not checked (--unsigned)"
else
  if /usr/bin/codesign --verify --strict --deep "$APP" 2>/dev/null; then
    pass "code signature" "valid, including the extension"
  else
    fail "the signature does not verify (codesign --verify --strict --deep)"
  fi

  ENTITLEMENTS=$(/usr/bin/codesign -d --entitlements - --xml "$APP" 2>/dev/null | /usr/bin/plutil -convert xml1 - -o - 2>/dev/null || true)
  if [[ "$ENTITLEMENTS" == *"$APP_GROUP"* ]]; then
    pass "app group entitlement" "$APP_GROUP"
  else
    fail "the signed app does not carry $APP_GROUP, so the widget reads an empty store"
  fi
  if [[ "$ENTITLEMENTS" == *"$TEAM_ID"* ]]; then
    pass "team" "$TEAM_ID"
  else
    fail "the signature is not for team $TEAM_ID"
  fi

  # `get-task-allow` is what makes a build debuggable, and what `storekitd` reads to decide that an
  # app is a development install: `scripts/shots.sh --review` puts it on one Debug build so the
  # review screenshot can have prices on it. A true one must never reach the store, which refuses a
  # debuggable binary. A distribution profile does not authorise it either, so the usual outcome is a
  # signing failure long before here, and "the usual outcome" is not something to upload on.
  #
  # The value is what matters, not the key. Xcode writes `get-task-allow` explicitly as false when it
  # signs Release with a distribution identity, so grepping for the name flags every correct archive
  # there is and stops the upload on the one build that was right.
  DEBUGGABLE=()
  for bundle in "$APP" "$WIDGET"; do
    [[ -d "$bundle" ]] || continue
    BUNDLE_ENTITLEMENTS=$(/usr/bin/codesign -d --entitlements - --xml "$bundle" 2>/dev/null \
      | /usr/bin/plutil -convert xml1 - -o - 2>/dev/null || true)
    TASK_ALLOW=$(printf '%s' "$BUNDLE_ENTITLEMENTS" \
      | /usr/bin/plutil -extract get-task-allow raw - -o - 2>/dev/null || echo absent)
    if [[ "$TASK_ALLOW" == "true" ]]; then
      DEBUGGABLE+=("$(basename "$bundle")")
    fi
  done
  if [[ ${#DEBUGGABLE[@]} -eq 0 ]]; then
    pass "not debuggable" "get-task-allow is not true"
  else
    fail "${DEBUGGABLE[*]} carries get-task-allow, which is a Debug entitlement the store rejects"
  fi
fi

# Without these a TestFlight crash report is a list of hexadecimal addresses.
DSYMS=$(find "$ARCHIVE/dSYMs" -maxdepth 1 -name "*.dSYM" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$DSYMS" -ge 2 ]]; then
  pass "debug symbols" "$DSYMS dSYMs"
else
  fail "only $DSYMS dSYMs: a crash from TestFlight would come back unsymbolicated"
fi

echo
if [[ "$FAILURES" -gt 0 ]]; then
  printf '\033[1;31mverify-archive:\033[0m %s problems. Do not upload this archive.\n' "$FAILURES" >&2
  exit 1
fi
if [[ "$SIGNED" -eq 0 ]]; then
  say "Archive assembles correctly: $VERSION ($BUILD), $LANGUAGE_COUNT languages, unsigned"
  printf '  Not uploadable as it stands: an unsigned archive cannot be exported for the store.\n'
else
  say "Archive is uploadable: $VERSION ($BUILD), $LANGUAGE_COUNT languages, signed for $TEAM_ID"
fi
