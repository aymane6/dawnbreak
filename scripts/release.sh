#!/usr/bin/env bash
#
# Generate, check, test, archive, verify, export, upload. The whole path to TestFlight.
#
#     scripts/release.sh                 # all of it, ending in a build on TestFlight
#     scripts/release.sh --dry-run       # everything except the upload
#     scripts/release.sh --unsigned      # generate, check, test, archive, verify: no credentials
#     scripts/release.sh --review        # the strict preflight, for a store submission
#     scripts/release.sh --no-tests      # skip the two test suites (they take about four minutes)
#
# Output: build/Dawnbreak.xcarchive   the archive, with its dSYMs
#         build/export/Dawnbreak.ipa  what gets uploaded
#
# The order is the point. Every step here exists because the step after it cannot see what it would
# have caught:
#
#   xcodegen        project.yml is the source of truth; a stale .xcodeproj builds last week's
#                   entitlements and no error says so.
#   asc-preflight   reads the sources: stale catalogues, a listing promising more than the binary
#                   gives, a privacy manifest that is not in the widget's target.
#   provision       the certificate and the two profiles Release signs with, through the API,
#                   before the twenty minutes of build that would otherwise be wasted.
#   tests           the kit's logic and the app's localization, on a simulator.
#   archive         Release, generic/platform=iOS, so what is verified is what is uploaded.
#   verify-archive  reads the built bundles: twelve compiled .lproj folders, the manifest in both
#                   bundles, matching build numbers, arm64 only, a signature that verifies.
#   validate        Apple's own check, which costs nothing and reports ITMS errors by number.
#   upload          last, because it is the only step that cannot be undone.
#
# Credentials, which are never in this repo:
#
#     export ASC_KEY_ID=XXXXXXXXXX          # the App Store Connect API key id
#     export ASC_ISSUER_ID=xxxxxxxx-xxxx-…  # the issuer id, from Users and Access → Integrations
#
# and the private key at ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8, which is where
# altool looks and which .gitignore refuses to track. A key is downloadable exactly once; keep it
# out of the working tree and out of the shell history.
#
# Signing does not go through `xcodebuild -allowProvisioningUpdates`, and cannot: that flag
# authenticates against developerservices2.apple.com, which refuses an App Store Connect API key
# ("Authentication failed: Make sure a bearer token was provided…") and wants the session an
# interactive Apple ID login produces. `scripts/provision.py` uses the public API, which does accept
# the key, to make the certificate and the two App Store profiles, and Release signs manually
# against them. Nothing here needs Xcode to have been signed in.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
BUILD="$ROOT/build"
ARCHIVE="$BUILD/Dawnbreak.xcarchive"
EXPORT="$BUILD/export"
IPA="$EXPORT/Dawnbreak.ipa"
LOGS="$BUILD/logs"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mrelease:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mrelease:\033[0m %s\n' "$*" >&2; exit 1; }

DRY_RUN=0
RUN_TESTS=1
SIGNED=1
PREFLIGHT_STAGE="--testflight"
for argument in "$@"; do
  case "$argument" in
    --dry-run)  DRY_RUN=1 ;;
    --unsigned) SIGNED=0; DRY_RUN=1 ;;
    --no-tests) RUN_TESTS=0 ;;
    --review)   PREFLIGHT_STAGE="" ;;
    *) die "unknown option $argument (see the header of this script)" ;;
  esac
done

for tool in xcodegen xcodebuild python3; do
  command -v "$tool" >/dev/null || die "$tool is not installed"
done
mkdir -p "$LOGS"

# Resolved before anything is built, because the archive is the first step that signs: finding out
# at the export that there are no credentials is twenty minutes of build wasted.
if [[ "$SIGNED" -eq 1 ]]; then
  : "${ASC_KEY_ID:?set ASC_KEY_ID (App Store Connect → Users and Access → Integrations), or pass --unsigned}"
  : "${ASC_ISSUER_ID:?set ASC_ISSUER_ID (the issuer id on the same page)}"

  KEY_FILE=""
  for folder in "./private_keys" "$HOME/private_keys" "$HOME/.private_keys" "$HOME/.appstoreconnect/private_keys"; do
    [[ -f "$folder/AuthKey_$ASC_KEY_ID.p8" ]] && KEY_FILE="$folder/AuthKey_$ASC_KEY_ID.p8" && break
  done
  [[ -n "$KEY_FILE" ]] || die "no AuthKey_$ASC_KEY_ID.p8 in ~/.appstoreconnect/private_keys/"
fi

# ---------------------------------------------------------------------------
# 1. The project, from project.yml
# ---------------------------------------------------------------------------

say "Generating the project"
xcodegen generate --quiet

# ---------------------------------------------------------------------------
# 2. Preflight
# ---------------------------------------------------------------------------

say "Preflight"
# shellcheck disable=SC2086  # deliberately unquoted: an empty stage means "check everything"
python3 scripts/asc-preflight.py $PREFLIGHT_STAGE || die "preflight failed, nothing was built"

# ---------------------------------------------------------------------------
# 3. The signing assets
# ---------------------------------------------------------------------------

# Before the tests rather than after: it costs two seconds and four API calls, and it is the step
# most likely to need a human, so it should fail while there is still nothing to throw away.
if [[ "$SIGNED" -eq 1 ]]; then
  say "Provisioning"
  python3 scripts/provision.py || die "the Release build cannot be signed yet, see above"
fi

# ---------------------------------------------------------------------------
# 4. Tests
# ---------------------------------------------------------------------------

if [[ "$RUN_TESTS" -eq 1 ]]; then
  say "Testing the kit"
  swift test --package-path DawnbreakKit 2>&1 | tail -3

  # A concrete simulator, because `xcodebuild test` will not take a generic one. The screenshot
  # device is reused when it exists so a full run does not boot a second simulator.
  UDID=$(xcrun simctl list devices available | awk -F'[()]' '/Dawnbreak 6\.9/ {print $2; exit}')
  [[ -n "$UDID" ]] || UDID=$(xcrun simctl list devices available | awk -F'[()]' '/iPhone/ {print $2; exit}')
  [[ -n "$UDID" ]] || die "no iOS simulator is available to run the tests on"

  say "Testing the app (simulator $UDID)"
  xcodebuild test \
    -project Dawnbreak.xcodeproj \
    -scheme Dawnbreak \
    -destination "platform=iOS Simulator,id=$UDID" \
    -only-testing:DawnbreakTests \
    -derivedDataPath "$BUILD/derived" \
    -quiet > "$LOGS/test.log" 2>&1 || {
      tail -40 "$LOGS/test.log" >&2
      die "the app tests failed, see build/logs/test.log"
    }
  say "Tests passed"
else
  warn "tests skipped"
fi

# ---------------------------------------------------------------------------
# 5. Archive
# ---------------------------------------------------------------------------

# Removed rather than overwritten: xcodebuild merges into an existing archive, so a stale dSYM or a
# removed resource can survive into the upload.
rm -rf "$ARCHIVE" "$EXPORT"

SIGNING=()
[[ "$SIGNED" -eq 0 ]] && SIGNING=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="")

say "Archiving (Release$([[ "$SIGNED" -eq 0 ]] && printf ', unsigned'))"
xcodebuild archive \
  -project Dawnbreak.xcodeproj \
  -scheme Dawnbreak \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  ${SIGNING[@]:+"${SIGNING[@]}"} \
  -quiet > "$LOGS/archive.log" 2>&1 || {
    tail -40 "$LOGS/archive.log" >&2
    die "the archive failed, see build/logs/archive.log"
  }

# ---------------------------------------------------------------------------
# 6. Verify what was actually built
# ---------------------------------------------------------------------------

say "Verifying the archive"
if [[ "$SIGNED" -eq 0 ]]; then
  scripts/verify-archive.sh --unsigned "$ARCHIVE" || die "the archive is not what it should be"
  say "Unsigned run: stopping before the export, which needs a distribution certificate"
  exit 0
fi
scripts/verify-archive.sh "$ARCHIVE" || die "the archive is not uploadable"

# ---------------------------------------------------------------------------
# 7. Export
# ---------------------------------------------------------------------------

say "Exporting the .ipa"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist Configuration/ExportOptions.plist \
  -exportPath "$EXPORT" \
  -quiet > "$LOGS/export.log" 2>&1 || {
    tail -40 "$LOGS/export.log" >&2
    die "the export failed, see build/logs/export.log"
  }
[[ -f "$IPA" ]] || die "the export produced no .ipa in ${EXPORT/#$ROOT\//}"
say "$(du -h "$IPA" | cut -f1) at ${IPA/#$ROOT\//}"

# ---------------------------------------------------------------------------
# 8. Upload
# ---------------------------------------------------------------------------

if [[ "$DRY_RUN" -eq 1 ]]; then
  say "Dry run: stopping before the upload"
  exit 0
fi

# Apple's own validation first. It reports the same ITMS numbers as the upload, does not consume
# anything, and is the difference between finding out now and finding out by email.
say "Validating with App Store Connect"
xcrun altool --validate-app \
  --type ios \
  --file "$IPA" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID" \
  --output-format json > "$LOGS/validate.json" 2>&1 || {
    python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('product-errors', sys.argv[1]))" \
      "$LOGS/validate.json" >&2 || cat "$LOGS/validate.json" >&2
    die "App Store Connect rejected the build before upload"
  }

say "Uploading to TestFlight"
xcrun altool --upload-app \
  --type ios \
  --file "$IPA" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID" \
  --output-format json > "$LOGS/upload.json" 2>&1 || {
    python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('product-errors', sys.argv[1]))" \
      "$LOGS/upload.json" >&2 || cat "$LOGS/upload.json" >&2
    die "the upload failed, see build/logs/upload.json"
  }

VERSION=$(/usr/bin/plutil -extract ApplicationProperties.CFBundleShortVersionString raw -o - "$ARCHIVE/Info.plist")
BUILD_NUMBER=$(/usr/bin/plutil -extract ApplicationProperties.CFBundleVersion raw -o - "$ARCHIVE/Info.plist")
say "Uploaded $VERSION ($BUILD_NUMBER)."
cat <<'NEXT'

  Processing takes ten to thirty minutes. Then, in App Store Connect:

    TestFlight → the build → Manage → answer the encryption question if it is asked
                 (it should not be: ITSAppUsesNonExemptEncryption is already declared false)
    TestFlight → Internal Testing → add yourself, install from the TestFlight app

  For the store submission afterwards, everything else is already in the repo:

    metadata/<locale>/*.txt          name, subtitle, keywords, description, promotional text
    metadata/review_information/     the notes and the contact
    build/shots/framed/<locale>/     the screenshots, 1320×2868
    docs/                            the privacy policy and support pages GitHub Pages serves

  Bump CURRENT_PROJECT_VERSION in project.yml before the next upload: App Store Connect
  refuses a build number it has already seen.
NEXT
