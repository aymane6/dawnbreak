# Dawnbreak

An iOS alarm clock that will not switch off until you have done something. Solve arithmetic, walk
thirty steps, photograph the kitchen sink, draw a bicycle, do squats in front of the camera. Press
Stop instead and the alarm comes back five minutes later.

Twelve languages, no account, no login, no server. Every alarm and every record stays in the app's
own container on the phone.

```
Dawnbreak/
├── Sources/            the app (SwiftUI, iOS 26)
├── Widget/             the Live Activity and the home screen widget
├── DawnbreakKit/       the logic: missions, store, stats, entitlements (a Swift package)
├── Tests/              unit tests that need the app bundle
├── UITests/            the smoke test and the screenshot run
├── Resources/          the string catalogues, the icon, the sounds, the privacy manifest
├── scripts/            the generators, the screenshot run, preflight, release
├── metadata/           generated: the App Store listing, twelve locales
├── docs/               generated: the marketing, privacy and support pages, twelve languages
└── project.yml         the one source of truth for the Xcode project
```

## The missions

Twelve, and the free tier keeps the three that need no hardware and no setup.

| Mission | What it asks | Needs | Free |
| --- | --- | --- | --- |
| Math | Arithmetic, one to four digits | | yes |
| Shake | Shake the phone N times | accelerometer | yes |
| Breathe | Guided breathing cycles | | yes |
| Memory | Reproduce a tile pattern | | |
| Sequence | Repeat a growing colour sequence | | |
| Typing | Retype a sentence, in your language | | |
| Steps | Walk N steps | pedometer | |
| Squats | Squats counted by the front camera | camera | |
| Photo | Photograph an object you registered | camera, setup | |
| Barcode | Scan a barcode you registered | camera, setup | |
| Draw | Draw a named object, recognised on device | | |
| Flap | Clear a lap of the side-scroller | | |

Four difficulties, up to ten rounds per alarm, and an emergency exit in Settings that is on by
default: no alarm can trap anybody.

## Free and Pro

| | Free | Pro |
| --- | --- | --- |
| Alarms | 1 | 25 |
| Rounds per alarm | 1 | 10 |
| Missions | 3 | 12 |
| Difficulty | up to medium | all four |
| History | 7 days | 90 days |

Pro is three products against one entitlement: monthly, yearly and a lifetime purchase
(`com.aymbam.dawnbreak.pro.{monthly,yearly,lifetime}`). `Transaction.currentEntitlements` is the
only source of truth; nothing is cached, because a cached flag survives a refund and a cached
absence locks a paying user out on a fresh install.

These numbers are not written twice. `Entitlement` in the kit decides them, and
`scripts/asc-preflight.py` checks the store listing and the reviewer's notes against it. A listing
that promises more than the binary gives is a 2.3.1 rejection.

## Languages

Twelve, all fully translated, including the sentences the typing mission asks you to retype:
English, Arabic, German, Spanish, French, Hindi, Italian, Japanese, Korean, Brazilian Portuguese,
Russian and Simplified Chinese. Five script classes, so RTL, tall glyphs and no-space line breaking
are all exercised by the layout and by the screenshot compositor.

Arabic is right to left throughout and writes its numbers in Arabic-Indic digits, including the
maths keypad and the problem above it. `scripts/make_strings.py` refuses to build a catalogue with
Latin digits in an Arabic value.

## Requirements

* macOS with Xcode 26 or later, and an iOS 26 simulator
* [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
* Python 3.11+ with Pillow (`python3 -m pip install pillow`), for the preflight's image checks
* An Apple Developer account, for anything that touches a device or App Store Connect

## Build and run

```sh
xcodegen generate       # writes Dawnbreak.xcodeproj from project.yml
open Dawnbreak.xcodeproj
```

`Dawnbreak.xcodeproj` is generated and gitignored, along with the two Info.plists and the two
entitlements files in `Configuration/`. Never edit them: edit `project.yml` and regenerate. The
scheme is wired to `Configuration/Dawnbreak.storekit`, so the paywall works in the simulator with no
sandbox account.

AlarmKit will not ring in the simulator the way it does on a device. The missions, the paywall, the
stats and every screen work; to see an alarm actually break through a Focus mode, run on hardware.

## Everything generated

Four generators, each with its own checks. All of them are idempotent and safe to re-run, and
`asc-preflight.py` fails if what is on disk is not what they would write.

```sh
python3 scripts/make_strings.py      # Resources/{Localizable,InfoPlist}.xcstrings
python3 scripts/make_metadata.py     # metadata/  (the App Store listing)
python3 scripts/make_pages.py        # docs/      (the pages GitHub Pages serves)
scripts/shots.sh                     # build/shots/framed/  (the screenshots)
```

`make_strings.py` exists because about a fifth of the keys never appear as a literal in the source:
`MissionKind.titleKey` builds `"mission.\(rawValue).title"`, and Xcode's extractor cannot see that.
It fails rather than writing a bad catalogue when a key on screen has no row, when a row is
unreachable, when a translation's format specifiers differ from the English ones, when a plural row
is not that locale's CLDR set, and when an Arabic value types a Latin digit.

## Screenshots

```sh
scripts/shots.sh                 # all twelve languages, about twenty minutes
scripts/shots.sh fr-FR ja        # only these, by App Store Connect locale code
scripts/shots.sh --frame-only    # re-frame what is already in build/shots/raw
```

Six screens in each of the twelve languages, at 1320x2868 on an iPhone 17 Pro Max, which is the one
size App Store Connect still asks for. One build, twelve launches: the app is built for testing once
and relaunched per language, so the screenshots are of the same Release binary that gets archived.

The simulator is put into each language and resprung, which is what costs the run its twenty
minutes. Without it the status bar stays English, and the Arabic shots come out left to right.

The captions are burnt in per language by `scripts/frame-shots.swift`, from the same string tables
the app uses.

## Tests

```sh
swift test --package-path DawnbreakKit        # the logic: 80 tests, no simulator needed
xcodebuild test -scheme Dawnbreak -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

The kit's tests are property-based where it matters: "easy maths never asks for a negative answer"
is proved over 200 seeded draws, not hoped about one. The app's tests check what only the bundle can
answer: that every key the app builds at runtime resolves in all twelve languages, that the paywall
copy names its own price, and that the sounds are in the bundle.

## Release: TestFlight

```sh
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
scripts/release.sh
```

with the private key at `~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8`. Both are made in
App Store Connect under Users and Access, Integrations. The key is downloadable exactly once, and
`.gitignore` refuses to track `AuthKey_*.p8`.

`release.sh` runs the whole path and stops at the first thing that would fail later:

1. `xcodegen generate`, because a stale project builds last week's entitlements silently.
2. `scripts/asc-preflight.py --testflight`, which reads the sources.
3. Both test suites.
4. `xcodebuild archive`, Release, `generic/platform=iOS`.
5. `scripts/verify-archive.sh`, which reads the built bundles.
6. `xcodebuild -exportArchive` into `build/export/Dawnbreak.ipa`.
7. `xcrun altool --validate-app`, which costs nothing and reports ITMS errors by number.
8. `xcrun altool --upload-app`, last, because it is the only step that cannot be undone.

`--dry-run` stops before the upload. `--no-tests` skips step 3. `--review` runs the strict preflight
instead of the TestFlight one.

Bump `CURRENT_PROJECT_VERSION` in `project.yml` before each upload: App Store Connect refuses a
build number it has already seen.

### What the two checks cover

`asc-preflight.py` reads the repository: stale catalogues, a listing over a character limit, an app
group spelled two ways, product ids that differ between the Swift and the StoreKit configuration, a
missing privacy manifest, an icon with an alpha channel, a purpose string for an API the app never
calls, a paywall gate with no headline, screenshots at the wrong size, and every number in the
reviewer's notes against the Swift that decides it.

`verify-archive.sh` reads the built bundles, which is the only place some of it exists: twelve
compiled `.lproj` folders in both the app and the extension, the privacy manifest copied into both,
matching build numbers, `arm64` and no simulator slice, a signature that verifies, the app group in
the signed entitlements, and dSYMs for symbolicated crash reports.

Run either on its own at any time.

## Release: App Store

Everything the submission needs is in the repo:

| | |
| --- | --- |
| `metadata/<locale>/name.txt` and the rest | name, subtitle, keywords, promotional text, description, release notes |
| `metadata/review_information/` | the reviewer's notes and the contact |
| `metadata/{copyright,primary_category,secondary_category}.txt` | set once |
| `build/shots/framed/<locale>/` | six screenshots each, 1320x2868 |
| `docs/privacy.html` | the privacy policy the listing links, in twelve languages |

The layout is fastlane `deliver`'s, so `fastlane deliver` uploads it as it stands. It is equally
readable by hand: one file per field, which is a legible diff in a way a JSON string is not.

Three things are not in the repo and cannot be:

1. **The app record.** Create it once in App Store Connect with bundle id `com.aymbam.dawnbreak`,
   the name from `metadata/en-US/name.txt`, primary language English.
2. **The three in-app purchases.** Ids, prices and durations are in
   `Configuration/Dawnbreak.storekit`; recreate them in App Store Connect and attach the same
   localized names. A subscription needs a review screenshot of the paywall, which is
   `build/shots/framed/en-US/`.
3. **The review contact.** `CONTACT` in `scripts/make_metadata.py` still holds a placeholder email
   and phone number, and the preflight fails on both by design. Put real ones in, re-run
   `make_metadata.py`. Apple uses them when a review stalls, and an invented value costs a review
   cycle rather than saving one.

The privacy answers in App Store Connect are "Data Not Collected", which is what
`Resources/PrivacyInfo.xcprivacy` declares and what the privacy policy says. Nothing here has an
analytics SDK, a network call, or a tracking permission.

## The pages

`docs/` is served by GitHub Pages and holds three pages in twelve languages each: the marketing
page, the privacy policy and the support page. The listing links to all three, and a reviewer opens
the privacy policy, so a 404 there is an immediate rejection.

Enable it once, after the first push:

1. The repository has to be named `dawnbreak` and be public. The URLs are baked into the listing as
   `https://aymane6.github.io/dawnbreak/`, so a different name means editing `scripts/strings/store.py`
   and re-running `make_metadata.py` and `make_pages.py`.
2. Settings, Pages, Source: Deploy from a branch. Branch `main`, folder `/docs`.
3. Wait for the first deploy, then open `https://aymane6.github.io/dawnbreak/privacy.html`.

Language follows the browser, with a picker on the page, `?lang=ja` to force one, and English as the
fallback. Every language is in the file, so it works with JavaScript off. There is no build step and
no Jekyll: `docs/.nojekyll` keeps GitHub from running one.

## A note on what this is

Dawnbreak is an independent reimplementation of the idea behind mission-based alarm clocks, written
from scratch in Swift 6 and SwiftUI against iOS 26's AlarmKit. It shares no code, assets, or text
with any other app.
