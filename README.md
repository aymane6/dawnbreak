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
├── DawnbreakKit/       the logic: missions, store, stats (a Swift package)
├── Tests/              unit tests that need the app bundle
├── UITests/            the smoke test and the screenshot run
├── Resources/          the string catalogues, the icon, the sounds, the privacy manifest
├── scripts/            the generators, the screenshot run, preflight, release
├── metadata/           generated: the App Store listing, twelve locales
├── docs/               generated: the marketing, privacy and support pages, twelve languages
└── project.yml         the one source of truth for the Xcode project
```

## The missions

Twelve, all of them available on first launch.

| Mission | What it asks | Needs |
| --- | --- | --- |
| Math | Arithmetic, one to four digits | |
| Shake | Shake the phone N times | accelerometer |
| Breathe | Guided breathing cycles | |
| Memory | Reproduce a tile pattern | |
| Sequence | Repeat a growing colour sequence | |
| Typing | Retype a sentence, in your language | |
| Steps | Walk N steps | pedometer |
| Squats | Squats counted by the front camera | camera |
| Photo | Photograph an object you registered | camera, setup |
| Barcode | Scan a barcode you registered | camera, setup |
| Draw | Draw a named object, recognised on device | |
| Flap | Clear a lap of the side-scroller | |

Four difficulties, up to ten rounds per alarm, and a way out on every mission screen, the × in its
corner, that no setting can hide: no alarm can trap anybody.

## Free

All of it, for everybody. Twelve missions, four difficulties, up to ten rounds an alarm, as many
alarms as a week needs, ninety days of history. No subscription, no in-app purchase, no advertising,
no account, and the app links no StoreKit at all.

1.0.0 was built the other way, with three products against one `Entitlement` and a paywall, and they
came out on 2026-09-03 for a reason worth writing down: **App Store Connect's API cannot attach an
in-app purchase to a review submission.** `POST /v1/reviewSubmissionItems` has a relationship for an
`appStoreVersion` and for an app event, and none for a `subscription` or an `inAppPurchaseV2`; both
were tried and both answered 409. So a version carrying products can only be sent to Apple by hand,
through the web UI, ticking three boxes. Everything else in this repository is a script that can be
re-run and read in a diff, and the choice was between one step that is neither and an app that does
not sell anything. The app does not sell anything.

The four numbers above are not written twice. `MissionKind`, `MissionConfig.maxRounds` and
`StatsView.Window` decide them, and `scripts/asc-preflight.py` checks the store listing and the
reviewer's notes against the Swift. A listing that promises more than the binary gives is a 2.3.1
rejection, and the same check now also refuses a StoreKit import, a `.storekit` file, a product id
and a price quoted in any of the twelve descriptions.

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

`Dawnbreak.xcodeproj` is generated and gitignored, along with the two Info.plists and the three
entitlements files in `Configuration/`. Never edit them: edit `project.yml` and regenerate.

AlarmKit will not ring in the simulator the way it does on a device. The missions, the stats and
every screen work; to see an alarm actually break through a Focus mode, run on hardware.

## Everything generated

Four generators, each with its own checks. All of them are idempotent and safe to re-run, and
`asc-preflight.py` fails if what is on disk is not what they would write.

```sh
python3 scripts/make_strings.py      # Resources/{Localizable,InfoPlist}.xcstrings
python3 scripts/make_metadata.py     # metadata/  (the App Store listing)
python3 scripts/make_pages.py        # docs/      (the pages the website serves, see below)
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

There used to be a thirteenth image here, and a `--review` flag to take it: Apple submits every
in-app purchase with a picture of the screen that sells it, and rendering that screen with real
prices on a simulator took a unit test, a `SKTestSession`, a `.storekit` file and a Debug-only
`get-task-allow` entitlement. All of it went with the products. What is left is
`Configuration/Dawnbreak-Debug.entitlements`, which XcodeGen writes from `project.yml` to give the
unit-test bundle the app group, and nothing more.

The path the review notes send a reviewer down is checked by `SmokeTests`, which runs in every test
run rather than only before a submission.

## Tests

```sh
swift test --package-path DawnbreakKit        # the logic, no simulator needed
xcodebuild test -scheme Dawnbreak -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

The kit's tests are property-based where it matters: "easy maths never asks for a negative answer"
is proved over 200 seeded draws, not hoped about one. The app's tests check what only the bundle can
answer: that every key the app builds at runtime resolves in all twelve languages, that the twelve
compiled `.lproj` folders are really there, and that the fourteen sounds are in the bundle.

## Release: TestFlight

```sh
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
scripts/release.sh
```

with the private key at `~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8`. Both are made in
App Store Connect under Users and Access, Integrations. The key is downloadable exactly once, and
`.gitignore` refuses to track `AuthKey_*.p8`.

Those three are all the credentials needed, including for signing, and no Apple ID has to be signed
in to Xcode. What does the signing is `scripts/provision.py`, which `release.sh` runs for you:

```sh
python3 scripts/provision.py    # App IDs, App Groups capability, certificate, both profiles
```

It registers both App IDs, enables the App Groups capability on them, creates one Apple Distribution
certificate (private key generated locally, imported into the login keychain, written nowhere else)
and issues the two App Store profiles `project.yml` signs Release against, then installs them where
Xcode looks. Re-running it is safe: it reuses whatever is already right and reissues whatever is not.

It exists because `xcodebuild -allowProvisioningUpdates` cannot be used here at all. That flag
authenticates against `developerservices2.apple.com`, and that host rejects an App Store Connect API
key outright (`Authentication failed: Make sure a bearer token was provided…`, whatever the token's
audience, lifetime or scope), because it wants the session an interactive Apple ID login produces.
The public API accepts the same key for certificates, profiles and identifiers, which is everything
except one thing, so Release signs manually against what the API made.

The one thing is the App Group. `group.com.aymbam.dawnbreak` has to be created once by hand at
developer.apple.com and ticked on both App IDs; there is no endpoint for it. `provision.py` prints
those three clicks and exits 1 until they are done, because a profile issued before the group exists
authorises no group at all and the archive then fails with four errors that barely mention it.

`release.sh` runs the whole path and stops at the first thing that would fail later:

1. `xcodegen generate`, because a stale project builds last week's entitlements silently.
2. `scripts/asc-preflight.py --testflight`, which reads the sources.
3. `scripts/provision.py`, before the twenty minutes of build a missing profile would waste.
4. Both test suites.
5. `xcodebuild archive`, Release, `generic/platform=iOS`.
6. `scripts/verify-archive.sh`, which reads the built bundles.
7. `xcodebuild -exportArchive` into `build/export/Dawnbreak.ipa`.
8. `xcrun altool --validate-app`, which costs nothing and reports ITMS errors by number.
9. `xcrun altool --upload-app`, last, because it is the only step that cannot be undone.

`--dry-run` stops before the upload. `--no-tests` skips step 4. `--review` runs the strict preflight
instead of the TestFlight one. `--unsigned` needs no credentials at all: it runs steps 1 to 5 with
`CODE_SIGNING_ALLOWED=NO` and verifies the archive with the three signature checks skipped, which is
how you prove the bundle assembles on a machine with no distribution certificate.

Bump `CURRENT_PROJECT_VERSION` in `project.yml` before each upload: App Store Connect refuses a
build number it has already seen.

### What the two checks cover

`asc-preflight.py` reads the repository: stale catalogues, a listing over a character limit, an app
group spelled two ways, a missing privacy manifest, an icon with an alpha channel, a purpose string
for an API the app never calls, screenshots at the wrong size, anything that would make the app sell
something again, and every number in the reviewer's notes against the Swift that decides it.

`verify-archive.sh` reads the built bundles, which is the only place some of it exists: twelve
compiled `.lproj` folders in both the app and the extension, the privacy manifest copied into both,
matching build numbers, `arm64` and no simulator slice, a signature that verifies, the app group in
the signed entitlements, no `get-task-allow` in either bundle, and dSYMs for symbolicated crash
reports.

Run either on its own at any time.

## Release: App Store

```sh
python3 scripts/publish.py           # the listing: copy, screenshots, categories, review details
python3 scripts/submit.py            # what would go to Apple
python3 scripts/submit.py --send     # and then, once
```

The same three credentials as TestFlight and nothing else; all of them share `scripts/asc.py` with
`release.sh`. They look everything up before writing it, so a second run edits what the first one
made instead of making another one, and they stop with the same sentence if the app record does not
exist yet.

Everything they send is in the repo:

| | |
| --- | --- |
| `metadata/<locale>/name.txt` and the rest | name, subtitle, keywords, promotional text, description, release notes |
| `metadata/review_information/` | the reviewer's notes and the contact |
| `metadata/{copyright,primary_category,secondary_category}.txt` | set once |
| `build/shots/framed/<locale>/` | six screenshots each, 1320x2868 |
| `docs/privacy.html` | the privacy policy the listing links, in twelve languages |

One file per field, which is a legible diff in a way a JSON payload is not, and the same layout
fastlane's `deliver` reads for metadata. Nothing here runs fastlane. `publish.py` uploads the files
themselves rather than asking the generators again, so what Apple receives is what `git diff` showed.

`publish.py` writes the app info (name, subtitle and privacy URL in twelve languages, plus the two
categories), the age rating questionnaire, version 1.0.0, the twelve version localizations, the
review details, the content rights declaration, a free price schedule in every territory, and the
seventy-two screenshots into the 6.9-inch set; attaches the newest processed build; and stages the
review submission. It stops there, and staging is what makes the rest of this readable: adding the
version to a submission is the only call in the API that answers with everything the version is still
missing, each reason against the resource it belongs to.

`submit.py` is the one that sends, and it is a second script rather than a flag because writing the
listing is reversible and this is not: a submitted review submission can only be cancelled, and
cancelling one is documented to strand whatever else was in it. It re-reads the draft rather than
trusting the run before it, refuses an empty draft, refuses a version in a state Apple will not take,
refuses a version with no build or a build that is not `VALID`, and prints all of that before it will
accept `--send`. Without `--send` it sends nothing.

Three things stay with a signed-in human, because Apple exposes them nowhere else: the API answers
`POST /v1/apps` with `The resource 'apps' does not allow 'CREATE'`, has no app-group resource at all,
and has no resource of any name for the app privacy answers.

1. **The app record.** Create it once in App Store Connect with bundle id `com.aymbam.dawnbreak`,
   the name from `metadata/en-US/name.txt`, primary language English. Nothing can be uploaded to
   TestFlight before it exists: the upload is rejected with "No suitable application records were
   found".
2. **The App Group.** `group.com.aymbam.dawnbreak`, at developer.apple.com, ticked on both App IDs.
   See the TestFlight section above; `scripts/provision.py` does the rest.
3. **The app privacy answers.** Distribution → Confidentialité de l'app → Démarrer → "Non, nous ne
   collectons aucune donnée via cette app" → Publier. Published, not merely saved: a saved answer
   still fails the submission with "You must have published answers to your app's data usages". This
   is the same claim `Resources/PrivacyInfo.xcprivacy` makes with an empty
   `NSPrivacyCollectedDataTypes` and the privacy policy makes in twelve languages. Nothing here has
   an analytics SDK, a network call, or a tracking permission.

Read the version page in App Store Connect the way a reviewer will, then `scripts/submit.py --send`.
Re-running `publish.py` while a draft exists changes nothing and says so: a staged version takes no
metadata edits, and the way back to editing is to remove the item from the draft, which flips the
version to `DEVELOPER_REJECTED` and makes it editable again.

## The pages

`docs/` holds four pages in twelve languages each: the marketing page, the privacy policy, the terms
of use and the support page. The listing links three of them and Settings links two, and Apple reads
the privacy policy before a human opens the app, so a 404 on any of them is a rejection rather than a
papercut. The terms page is not required of an app that sells nothing; it is there because Settings
links it, and because somebody installing an alarm clock is owed a plain statement of what it will
and will not do.

Live at [dawnbreak.app](https://dawnbreak.app/), on the app's own domain. The domain is registered at
OVH and its DNS is delegated to a Route 53 hosted zone; the pages themselves are in S3 behind
CloudFront. All of that is `infra/`, a CDK app:

```sh
cd infra
npx cdk deploy DawnbreakDns      # the hosted zone, and the four name servers to set at OVH
npx cdk deploy DawnbreakSite     # certificate, bucket, distribution, records, and docs/ itself
npx projen test                  # 11 tests, no account needed
```

In that order, and with a human step between them: `DawnbreakSite` cannot finish until the registrar
points at the zone, because the certificate is validated over public DNS. `DawnbreakDns` prints the
four name servers; they go into OVH's "use my own DNS" form with the Associated IP field left empty.

**Regenerating `docs/` publishes nothing.** The pages are a CDK asset, uploaded by the bucket
deployment inside `DawnbreakSite`, so a fresh `docs/` reaches nobody until that stack is deployed and
the edge invalidated. There is no push-to-deploy: `git push` moves the source and not the site. On
2026-09-03 that gap ran for a week. The app had been stripped of every purchase and `docs/` said so,
but the live pages still described a Dawnbreak Pro subscription, a restore button and a refund policy,
in twelve languages, on the exact URLs the App Store description links, and a reviewer would have
opened a subscription EULA for an app with nothing to buy. So after `make_pages.py`, deploy.

The URLs live in `scripts/strings/store.py` and nowhere else. `asc-preflight.py` compares them
against `docs/`, against every `https://` URL compiled into the app, and against the support address
filed with Apple; in review mode it also fetches all four and compares them with `docs/` byte for
byte, so a stale deploy fails the same way a 404 does. That check exists because the app once shipped
four legal links pointing at a username that did not exist, and every other check in the repository
passed; the byte comparison was added the day a 200 from last week's deploy counted as proof.

Language follows the browser, with a picker on the page, `?lang=ja` to force one, and English as the
fallback. Every language is in the file, so it works with JavaScript off. There is no build step and
no Jekyll: the pages are static HTML written by `make_pages.py`.

## A note on what this is

Dawnbreak is an independent reimplementation of the idea behind mission-based alarm clocks, written
from scratch in Swift 6 and SwiftUI against iOS 26's AlarmKit. It shares no code, assets, or text
with any other app.
