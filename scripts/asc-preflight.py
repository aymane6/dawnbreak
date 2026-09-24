#!/usr/bin/env python3
"""Everything App Store Connect will refuse, refused here first.

Run from the repo root:

    python3 scripts/asc-preflight.py                # everything, as if submitting for review
    python3 scripts/asc-preflight.py --testflight   # only what blocks a TestFlight build

Nothing here talks to Apple. Every check is a claim this project makes about itself that can be
verified locally, and every one of them has cost somebody a review cycle: a listing that promises
twelve missions to a binary that ships nine, an app group spelled two ways so the widget reads an
empty store, a screenshot with an alpha channel, a privacy manifest that is not there.

The two stages exist because they fail on different days. A TestFlight upload only needs a
well-formed, signed bundle; the review contact, the screenshots and the listing copy are not read
until the build is submitted for review. Running the strict stage by default means those are
already right when that day comes, instead of arriving as an email a fortnight later.

Exit code is 1 if anything failed, so `scripts/release.sh` can refuse to upload.
"""

from __future__ import annotations

import argparse
import json
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import make_metadata
import make_pages
import make_strings
from strings import LOCALES, pages, store

ROOT = Path(__file__).resolve().parent.parent

PROJECT = ROOT / "project.yml"
CONFIGURATION = ROOT / "Configuration"
INFO_PLIST = CONFIGURATION / "Dawnbreak-Info.plist"
WIDGET_INFO_PLIST = CONFIGURATION / "DawnbreakWidget-Info.plist"
ENTITLEMENTS = (
    CONFIGURATION / "Dawnbreak.entitlements",
    CONFIGURATION / "DawnbreakWidget.entitlements",
    # Not shipped and not archived: the Debug-only file the unit-test bundle signs with, which
    # adds `get-task-allow` so the tests can be attached to. Checked here because xcodegen
    # generates it, and because the app group in it has to be the same string as in the other two:
    # a test that reads a different group reads an empty store and passes for the wrong reason.
    CONFIGURATION / "Dawnbreak-Debug.entitlements",
)
XCODEPROJ = ROOT / "Dawnbreak.xcodeproj"
PRIVACY_MANIFEST = ROOT / "Resources" / "PrivacyInfo.xcprivacy"
ICON_SET = ROOT / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
FRAMED = ROOT / "build" / "shots" / "framed"
PREFERENCES = ROOT / "DawnbreakKit/Sources/DawnbreakKit/Store/Preferences.swift"
MISSION_KIND = ROOT / "DawnbreakKit/Sources/DawnbreakKit/Models/MissionKind.swift"
MISSION_CONFIG = ROOT / "DawnbreakKit/Sources/DawnbreakKit/Models/MissionConfig.swift"
STATS = ROOT / "Sources/Stats/StatsView.swift"
FILE_STORE = ROOT / "DawnbreakKit/Sources/DawnbreakKit/Store/JSONFileStore.swift"
ENVIRONMENT = ROOT / "Sources/App/AppEnvironment.swift"

APP_BUNDLE_ID = "com.aymbam.dawnbreak"
APP_GROUP = "group.com.aymbam.dawnbreak"

# The one screenshot size this project uploads. 6.9-inch is the only iPhone display size App Store
# Connect still requires, and every smaller device is served by scaling this one down.
SHOT_SIZE = (1320, 2868)

# How the review notes spell the numbers that come out of the Swift, so a limit changed in code is
# checked against the sentence a reviewer reads. Only the values the copy actually quotes: a number
# with no spelling here fails loudly rather than skipping its own check.
NUMBER_WORDS = {4: "four", 10: "ten", 12: "twelve", 90: "ninety"}

# Markers that mean somebody meant to come back to it. Case-sensitive on purpose: lowercase "todo"
# is a Spanish and Portuguese word that appears in the real listing copy.
PLACEHOLDERS = ("TODO", "FIXME", "TBD", "XXX", "example.com", "Lorem ipsum", "lorem ipsum")

CHECKS = []


def check(title: str, testflight: bool = True):
    """Registers a check. `testflight=False` marks one that only matters at review time."""
    def register(function):
        CHECKS.append((title, testflight, function))
        return function
    return register


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def plist(path: Path) -> dict:
    with path.open("rb") as handle:
        return plistlib.load(handle)


def generated(function, *arguments):
    """Calls a generator, turning its `sys.exit` into a returned message.

    The generators fail by exiting, which is right when they are the program and wrong here: one
    stale catalogue would end the run before the twenty other checks got to say anything.
    """
    try:
        return function(*arguments), None
    except SystemExit as stop:
        return None, str(stop)


# ---------------------------------------------------------------------------
# Generated files, against their generators
# ---------------------------------------------------------------------------

@check("the catalogues match their generator")
def catalogues():
    """Whether `make_strings.py` would write what is already on disk.

    The most likely failure in this file: a table edited under scripts/strings/ and the generator
    not re-run, so the build ships last week's copy in twelve languages. Invisible in a diff of the
    source, and invisible on screen unless you read the language that changed.
    """
    built, error = generated(make_strings.build)
    if error:
        return "not buildable", [error]

    problems = []
    for name, payload in zip(make_strings.CATALOGUES, built):
        path = ROOT / name
        if not path.exists():
            problems.append(f"{name} is missing, run scripts/make_strings.py")
        elif json.loads(read(path)) != payload:
            problems.append(f"{name} is stale, run scripts/make_strings.py")
    keys = sum(len(payload["strings"]) for payload in built)
    return f"{keys} keys × {len(LOCALES)} locales", problems


@check("the listing matches its generator", testflight=False)
def listing():
    """Every metadata/ file, against `store.py`, including the shared URLs and the review notes.

    Checked as well as regenerated because `make_metadata.py` deletes and rewrites the folder: what
    is on disk is only current if nobody has touched a table since. An overrun character limit is
    caught here too, because the generator's own checks run on the way through.
    """
    locales, error = generated(make_metadata.contract_locales)
    if error:
        return "unreadable", [error]
    _, error = generated(make_metadata.check_mission_count)
    if error:
        return "inconsistent", [error]
    for step in (make_metadata.check_coverage, make_metadata.check_lengths,
                 make_metadata.check_keywords, make_metadata.check_descriptions):
        _, error = generated(step, locales)
        if error:
            return "inconsistent", [error]

    problems = []

    def compare(path: Path, expected: str):
        if not path.exists():
            problems.append(f"{path.relative_to(ROOT)} is missing, run scripts/make_metadata.py")
        elif read(path) != expected.rstrip("\n") + "\n":
            problems.append(f"{path.relative_to(ROOT)} is stale, run scripts/make_metadata.py")

    for locale in locales:
        for name, table, _ in store.FIELDS:
            compare(ROOT / "metadata" / locale / f"{name}.txt", table[locale])
        for name, value in store.SHARED:
            compare(ROOT / "metadata" / locale / f"{name}.txt", value)

    compare(ROOT / "metadata" / "copyright.txt", store.COPYRIGHT)
    compare(ROOT / "metadata" / "primary_category.txt", make_metadata.PRIMARY_CATEGORY)
    compare(ROOT / "metadata" / "secondary_category.txt", make_metadata.SECONDARY_CATEGORY)
    compare(ROOT / "metadata" / "review_information" / "notes.txt", make_metadata.REVIEW_NOTES)
    for name, value in make_metadata.CONTACT.items():
        compare(ROOT / "metadata" / "review_information" / f"{name}.txt", value)

    return f"{len(locales)} locales × {len(store.FIELDS)} fields", problems


@check("the pages match their generator", testflight=False)
def site():
    """docs/ is what GitHub Pages serves, and the privacy policy a reviewer opens is in there.

    Stale HTML here is worse than stale copy in the app: the listing links to these three URLs, so a
    description promising that no data leaves the device, against a policy page that says something
    else, is a contradiction a reviewer reads before launching anything.
    """
    for step in (make_pages.check_shape, make_pages.check_urls):
        _, error = generated(step)
        if error:
            return "inconsistent", [error]

    problems = []
    for page in pages.PAGES:
        path = ROOT / "docs" / f"{page}.html"
        expected, error = generated(make_pages.page_html, page)
        if error:
            problems.append(error)
        elif not path.exists():
            problems.append(f"docs/{page}.html is missing, run scripts/make_pages.py")
        elif read(path) != expected:
            problems.append(f"docs/{page}.html is stale, run scripts/make_pages.py")
    return f"{len(pages.PAGES)} pages × {len(LOCALES)} languages", problems


@check("the Xcode project is generated and current")
def project_generated():
    """xcodegen's six outputs have to exist, and say what project.yml says.

    All six are gitignored, so on a fresh clone they are simply absent. Worse is the case where
    they exist and disagree with project.yml: the build succeeds, with yesterday's version number
    and yesterday's entitlements.

    Timestamps cannot answer this. xcodegen compares before it writes and leaves a file whose
    content already matches completely untouched, so an old mtime is the normal state of a current
    file. The only honest oracle is xcodegen itself: generate into a scratch tree and diff. That
    also catches the failure a timestamp never could, which is one of these five edited by hand.
    """
    problems = []
    for path in (XCODEPROJ, INFO_PLIST, WIDGET_INFO_PLIST, *ENTITLEMENTS):
        if not path.exists():
            problems.append(f"{path.relative_to(ROOT)} is missing, run xcodegen generate")
    if problems:
        return "not generated", problems

    if not shutil.which("xcodegen"):
        return "6 files, not verified (xcodegen is not installed)", problems

    # A farm of symlinks to every top-level entry, so the spec's source paths resolve, with a real
    # empty Configuration/ so the four generated files land somewhere they can be compared. The
    # hand-written files in that folder are linked back in: the spec does not mention them, but
    # leaving them out would be a lie about what the folder holds.
    generated_names = {path.name for path in (INFO_PLIST, WIDGET_INFO_PLIST, *ENTITLEMENTS)}
    farm = Path(tempfile.mkdtemp(prefix="dawnbreak-spec."))
    try:
        for entry in ROOT.iterdir():
            if entry != CONFIGURATION:
                (farm / entry.name).symlink_to(entry)
        (farm / CONFIGURATION.name).mkdir()
        for entry in CONFIGURATION.iterdir():
            if entry.name not in generated_names:
                (farm / CONFIGURATION.name / entry.name).symlink_to(entry)

        result = subprocess.run(
            ["xcodegen", "generate", "--spec", str(PROJECT),
             "--project-root", str(farm), "--project", str(farm), "--quiet"],
            capture_output=True, text=True, check=False,
        )
        if result.returncode != 0:
            return "not generated", [f"xcodegen rejects project.yml: {result.stderr.strip()}"]

        for path in (INFO_PLIST, WIDGET_INFO_PLIST, *ENTITLEMENTS):
            fresh = farm / CONFIGURATION.name / path.name
            if not fresh.exists():
                problems.append(f"project.yml no longer generates {path.name}")
            elif fresh.read_bytes() != path.read_bytes():
                problems.append(f"{path.relative_to(ROOT)} is stale, run xcodegen generate")
    finally:
        shutil.rmtree(farm, ignore_errors=True)

    return "6 files, 5 diffed against project.yml", problems


# ---------------------------------------------------------------------------
# Identifiers
# ---------------------------------------------------------------------------

@check("the app group is spelled the same in all six places")
def app_group():
    """One typo here does not fail to build; it gives the widget its own empty container.

    The app and the extension share a group only when the string matches exactly, and the symptom is
    a Live Activity with no alarm label rather than an error anybody sees at build time.
    """
    problems = []
    declared = re.search(r'static let appGroup = "([^"]+)"', read(FILE_STORE))
    if not declared:
        problems.append("JSONFileStore no longer declares appGroup")
    elif declared.group(1) != APP_GROUP:
        problems.append(f"JSONFileStore says {declared.group(1)}, expected {APP_GROUP}")

    if read(PROJECT).count(f"- {APP_GROUP}") != 2:
        problems.append(f"project.yml must declare {APP_GROUP} for both targets")

    for path in ENTITLEMENTS:
        if not path.exists():
            continue    # already reported by the generated-project check
        groups = plist(path).get("com.apple.security.application-groups")
        if groups != [APP_GROUP]:
            problems.append(f"{path.name} declares {groups}")
    return APP_GROUP, problems


@check("bundle ids nest under the app's")
def bundle_ids():
    """An app extension's id must be prefixed by its host app's, or the upload is rejected."""
    problems = []
    ids = sorted(set(re.findall(r"PRODUCT_BUNDLE_IDENTIFIER: (\S+)", read(PROJECT))))
    if APP_BUNDLE_ID not in ids:
        problems.append(f"no target declares {APP_BUNDLE_ID}")
    for identifier in ids:
        if identifier != APP_BUNDLE_ID and not identifier.startswith(APP_BUNDLE_ID + "."):
            problems.append(f"{identifier} is not under {APP_BUNDLE_ID}")
    return f"{len(ids)} ids under {APP_BUNDLE_ID}", problems


@check("the version is shaped like a version")
def version():
    """Up to three dot-separated numbers, an integer build, and both plists reading the settings.

    An extension whose CFBundleVersion disagrees with its host app is rejected at upload, which is
    why both plists hold `$(MARKETING_VERSION)` rather than a number: the build resolves it, so the
    two bundles cannot disagree. A literal number in either plist is what this looks for, because
    that is how they start disagreeing.
    """
    problems = []
    yaml = read(PROJECT)
    marketing = re.search(r'MARKETING_VERSION: "([^"]+)"', yaml)
    build = re.search(r"CURRENT_PROJECT_VERSION: (\S+)", yaml)
    if not marketing or not re.fullmatch(r"\d+(\.\d+){0,2}", marketing.group(1)):
        problems.append(f"MARKETING_VERSION is {marketing.group(1) if marketing else 'absent'}")
    if not build or not re.fullmatch(r"\d+", build.group(1)):
        problems.append(f"CURRENT_PROJECT_VERSION is {build.group(1) if build else 'absent'}")
    if problems:
        return "malformed", problems

    for path in (INFO_PLIST, WIDGET_INFO_PLIST):
        if not path.exists():
            continue
        values = plist(path)
        for key, setting, value in (
            ("CFBundleShortVersionString", "MARKETING_VERSION", marketing.group(1)),
            ("CFBundleVersion", "CURRENT_PROJECT_VERSION", build.group(1)),
        ):
            found = str(values.get(key))
            if found not in (f"$({setting})", value):
                problems.append(f"{path.name}: {key} is {found!r}, expected $({setting})")
    return f"{marketing.group(1)} ({build.group(1)})", problems


# ---------------------------------------------------------------------------
# The bundle
# ---------------------------------------------------------------------------

@check("the encryption question is already answered")
def encryption():
    """`ITSAppUsesNonExemptEncryption` stops the upload asking, and stops the build sitting in
    "Missing Compliance" until somebody notices. False is honest: this app has no encryption of its
    own and never opens a socket."""
    if not INFO_PLIST.exists():
        return "not generated", []      # the generated-project check owns this
    declared = plist(INFO_PLIST).get("ITSAppUsesNonExemptEncryption")
    problems = [] if declared is False else [f"ITSAppUsesNonExemptEncryption is {declared!r}"]
    return "non-exempt encryption: false", problems


@check("the privacy manifest is present and honest")
def privacy_manifest():
    """Required since iOS 17 for any bundle that calls a required-reason API.

    A missing manifest fails neither the build nor the upload: it produces an ITMS-91053 email
    afterwards, which is exactly why it is checked here. Both bundles need one, because the widget
    reads `UserDefaults` out of the shared group and has its own bundle id.
    """
    if not PRIVACY_MANIFEST.exists():
        return "absent", ["Resources/PrivacyInfo.xcprivacy is missing"]

    problems = []
    manifest = plist(PRIVACY_MANIFEST)
    if manifest.get("NSPrivacyTracking") is not False:
        problems.append("NSPrivacyTracking must be false: nothing here tracks anybody")
    if manifest.get("NSPrivacyCollectedDataTypes") != []:
        problems.append("NSPrivacyCollectedDataTypes must be empty, as the privacy policy claims")

    reasons = {
        entry.get("NSPrivacyAccessedAPIType"): entry.get("NSPrivacyAccessedAPITypeReasons", [])
        for entry in manifest.get("NSPrivacyAccessedAPITypes", [])
    }
    if "NSPrivacyAccessedAPICategoryUserDefaults" not in reasons:
        problems.append("both targets read UserDefaults, which is a required-reason API")
    elif "CA92.1" not in reasons["NSPrivacyAccessedAPICategoryUserDefaults"]:
        problems.append("the UserDefaults reason should be CA92.1, the app's own information")

    # The app target gets it from `- path: Resources`; the widget has to list it by name.
    if "Resources/PrivacyInfo.xcprivacy" not in read(PROJECT):
        problems.append("the widget target does not list Resources/PrivacyInfo.xcprivacy")
    return f"{len(reasons)} accessed API category, nothing collected", problems


@check("the purpose strings cover exactly the permissions asked for")
def purpose_strings():
    """Three permissions, three strings, no fourth, and all three translated.

    A purpose string for an API the app never calls is a question at review with no good answer. A
    missing one is a crash the moment the mission starts. An untranslated one is a Japanese app
    asking for the camera in English.
    """
    problems = []
    expected = {"NSAlarmKitUsageDescription", "NSCameraUsageDescription", "NSMotionUsageDescription"}
    declared = set(re.findall(r"(NS\w+UsageDescription):", read(PROJECT)))
    if declared != expected:
        problems.append(f"project.yml declares {sorted(declared)}, expected {sorted(expected)}")

    catalogue = json.loads(read(ROOT / "Resources" / "InfoPlist.xcstrings"))
    for key in sorted(expected & declared):
        localizations = catalogue["strings"].get(key, {}).get("localizations", {})
        missing = sorted(set(LOCALES) - set(localizations))
        if missing:
            problems.append(f"{key} is not translated into {missing}")
    return f"{len(declared)} permissions × {len(LOCALES)} languages", problems


@check("the app icon is one Apple accepts")
def icon():
    """1024×1024, square, and with no alpha channel, which is a hard rejection at upload.

    All three appearances are checked, not just the light one. The dark and tinted variants are drawn
    over a background the system provides, and this project's are opaque; a transparent one would be
    legal in the bundle but is not what these were drawn as.
    """
    from PIL import Image

    problems = []
    contents = json.loads(read(ICON_SET / "Contents.json"))
    filenames = sorted({image["filename"] for image in contents["images"] if image.get("filename")})
    if not filenames:
        return "empty", ["AppIcon.appiconset declares no image"]

    for filename in filenames:
        path = ICON_SET / filename
        if not path.exists():
            problems.append(f"{filename} is declared and missing")
            continue
        with Image.open(path) as image:
            if image.size != (1024, 1024):
                problems.append(f"{filename} is {image.size[0]}×{image.size[1]}, must be 1024×1024")
            if "A" in image.mode:
                problems.append(f"{filename} is {image.mode}: an app icon must have no alpha")
    return f"{len(filenames)} appearances, 1024×1024, opaque", problems


@check("the twelve languages agree with each other")
def localizations():
    """`CFBundleLocalizations`, the string tables and `CaptureLocale` are three lists of the same
    twelve languages. The App Store reads the first to decide which listing an iPhone is shown."""
    problems = []
    yaml = read(PROJECT)
    anchor = re.search(r"CFBundleLocalizations: &localizations\n((?:\s+- \S+\n)+)", yaml)
    if not anchor:
        return "not declared", ["project.yml has no CFBundleLocalizations anchor"]
    bundle = sorted(re.findall(r"- (\S+)", anchor.group(1)))
    if bundle != sorted(LOCALES):
        problems.append(f"CFBundleLocalizations is {bundle}, the app translates {sorted(LOCALES)}")

    # The widget's plist has to reuse the anchor rather than keep its own list: a lock screen in a
    # language the extension does not claim falls back to English halfway through the app.
    if "CFBundleLocalizations: *localizations" not in yaml:
        problems.append("the widget does not reuse the app's CFBundleLocalizations")

    listings = sorted(path.name for path in (ROOT / "metadata").iterdir()
                      if path.is_dir() and path.name != "review_information")
    expected, error = generated(make_metadata.contract_locales)
    if error:
        problems.append(error)
    elif listings != sorted(expected):
        problems.append(f"metadata/ has {listings}, CaptureLocale has {sorted(expected)}")
    return f"{len(bundle)} in the bundle, {len(listings)} listings", problems


# ---------------------------------------------------------------------------
# What the listing promises
# ---------------------------------------------------------------------------

def promised_numbers() -> dict[str, int | None]:
    """The four numbers the listing quotes, read out of the Swift that decides them."""
    kinds = read(MISSION_KIND)

    # Sliced the way make_metadata slices it: the nested `Capability` enum's cases sit on one line
    # and are not missions.
    body = kinds.partition("public enum MissionKind")[2].partition("public enum Capability")[0]
    missions = re.findall(r"^\s+case [a-z]\w*\s*(?://.*)?$", body, re.MULTILINE)
    difficulties = re.search(r"public enum Difficulty[^{]*\{\s*case ([^\n]+)", kinds)
    rounds = re.search(r"static let maxRounds = (\d+)", read(MISSION_CONFIG))
    # The longest window the statistics screen offers, which is what "ninety days of history"
    # means: nothing prunes the store, so the number a user can actually see is this enum's largest.
    windows = [int(value) for value in re.findall(r"case \w+ = (\d+)", read(STATS))]

    return {
        "missions": len(missions) or None,
        "difficulties": len(difficulties.group(1).split(",")) if difficulties else None,
        "rounds": int(rounds.group(1)) if rounds else None,
        "history": max(windows) if windows else None,
    }


@check("the listing promises the numbers the binary enforces", testflight=False)
def promises():
    """Every number in the reviewer's instructions, against the number in the Swift.

    This is the check that pays for the file. Twelve missions, four difficulties, ten rounds and
    ninety days are printed in the review notes and in twelve store descriptions; a limit changed in
    code and not in the copy is a 2.3.1 rejection, and it is invisible until a reviewer counts.
    """
    numbers = promised_numbers()
    problems = [f"could not read the {label} out of the Swift"
                for label, value in numbers.items() if value is None]
    if problems:
        return "unreadable", problems

    unspellable = sorted({value for value in numbers.values() if value not in NUMBER_WORDS})
    if unspellable:
        return "unspellable", [f"no English spelling for {unspellable}, add it to NUMBER_WORDS"]

    # Written the way the review notes write them, so a mismatch names the sentence to fix.
    promised = (
        f"{NUMBER_WORDS[numbers['missions']]} missions",
        f"{NUMBER_WORDS[numbers['difficulties']]} difficulties",
        f"{NUMBER_WORDS[numbers['rounds']]} rounds",
        f"{NUMBER_WORDS[numbers['history']]} days of history",
    )
    # Whitespace collapsed before matching: the notes are hard-wrapped at 96 columns, so "four
    # difficulties" is a phrase with a newline in the middle of it.
    notes = re.sub(r"\s+", " ", make_metadata.REVIEW_NOTES.lower())
    problems += [f'the review notes never say "{fragment}"'
                 for fragment in promised if fragment not in notes]

    if numbers["missions"] != store.MISSION_COUNT:
        problems.append(f"MissionKind has {numbers['missions']} missions, "
                        f"store.MISSION_COUNT says {store.MISSION_COUNT}")
    return (f"{numbers['missions']} missions, {numbers['difficulties']} difficulties, "
            f"{numbers['rounds']} rounds, {numbers['history']} days"), problems


@check("nothing in the app is for sale")
def nothing_for_sale():
    """The app is free, and this is what keeps that a fact rather than an intention.

    1.0.0 was built with three products and a paywall, and they came out on 2026-09-03 because App
    Store Connect's API cannot attach an in-app purchase to a review submission: `POST
    /v1/reviewSubmissionItems` has no relationship for `subscription` or `inAppPurchaseV2`, so a
    version carrying products can only be sent to Apple by hand. What was removed has to stay
    removed. Twelve store descriptions and the review notes now say there is nothing to buy, so a
    StoreKit import added back would make every one of them a false claim under 2.3.1, and the
    first reader of it would be a reviewer.
    """
    problems = []

    swift = sorted(path for directory in (ROOT / "Sources", ROOT / "DawnbreakKit" / "Sources")
                   for path in directory.rglob("*.swift"))
    for path in swift:
        source = read(path)
        if re.search(r"^\s*(@preconcurrency )?import StoreKit", source, re.MULTILINE):
            problems.append(f"{path.relative_to(ROOT)} imports StoreKit")
        # A product id is the bundle id with a suffix, which is also how the app group and two
        # dispatch queue labels are spelled, so only the ones that look like something sold count.
        for identifier in re.findall(rf'"{re.escape(APP_BUNDLE_ID)}\.(\w+)"', source):
            if identifier in ("monthly", "yearly", "lifetime", "pro", "premium"):
                problems.append(f"{path.relative_to(ROOT)} names a product id: {identifier}")

    for leftover in sorted(CONFIGURATION.glob("*.storekit")):
        problems.append(f"{leftover.relative_to(ROOT)} is a StoreKit configuration, and there is "
                        "no store to configure")

    # Apple's automated pass reads the description before a human opens the app. A price or a plan
    # in copy that the binary cannot honour is the cheapest rejection there is.
    for locale, description in sorted(store.DESCRIPTION.items()):
        for word in ("€", "$", "£", "/month", "/mois", "per month"):
            if word in description:
                problems.append(f"{locale}/description quotes a price ({word})")

    return f"{len(swift)} Swift files, no store", problems


@check("the emergency exit is on by default", testflight=False)
def emergency_exit():
    """The review notes promise no alarm can trap a user, and that the switch is on by default.

    It is the one sentence in those notes a reviewer can disprove without waiting for an alarm, and
    the default it describes is a single `?? true` in the kit.
    """
    on_by_default = re.search(
        r"emergencyExitEnabled = defaults\.object\(forKey: Key\.emergencyExit\) as\? Bool \?\? true",
        read(PREFERENCES),
    )
    problems = [] if on_by_default else ["Preferences no longer defaults emergencyExitEnabled to true"]
    if "on by default" not in make_metadata.REVIEW_NOTES:
        problems.append("the review notes no longer promise the default")
    return "on", problems


@check("the review contact reaches a person", testflight=False)
def review_contact():
    """Apple writes to this address and calls this number when a review stalls.

    Deliberately left failing until the real values are filled in. A placeholder does not fail the
    upload; it fails the review a fortnight later with "we were unable to contact you", and an
    invented value would be worse than an honest failure here.
    """
    problems = []
    contact = make_metadata.CONTACT
    email = contact.get("email_address", "")
    phone = contact.get("phone_number", "").replace(" ", "")
    if "example.com" in email or not re.fullmatch(r"[^@\s]+@[^@\s]+\.\w+", email):
        problems.append(f"email_address is {email!r}, put a real one in make_metadata.CONTACT")
    if not re.fullmatch(r"\+\d{8,15}", phone) or re.fullmatch(r"\+1?5{5,}\d*", phone):
        problems.append(f"phone_number is {phone!r}, put a real one in make_metadata.CONTACT")
    for name in ("first_name", "last_name"):
        if not contact.get(name, "").strip():
            problems.append(f"{name} is empty")
    return f"{contact.get('first_name')} {contact.get('last_name')}", problems


@check("no placeholder text reached the listing or the pages", testflight=False)
def placeholders():
    """The markers that mean a sentence was going to be finished later.

    Matched on word boundaries, which is not pedantry: the markers are case-sensitive already
    because lowercase "todo" is an ordinary Spanish and Portuguese word, and the uppercase form
    turned out to be one too. "SEIS TONOS NUEVOS, Y TODOS MÁS ALTOS" is a heading in the release
    notes, and a substring match read it as an unfinished sentence and blocked a release over it.
    """
    problems = []
    patterns = [(marker, re.compile(rf"(?<![A-Za-z]){re.escape(marker)}(?![A-Za-z])")) for marker in PLACEHOLDERS]
    for path in sorted((ROOT / "metadata").rglob("*.txt")) + sorted((ROOT / "docs").glob("*.html")):
        text = read(path)
        for marker, pattern in patterns:
            if pattern.search(text):
                problems.append(f"{path.relative_to(ROOT)} contains {marker!r}")
    return "clean", problems


# Which file answers which URL. Read by the check that looks at `docs/` and by the one that fetches
# the live site, because the second is only worth anything if it is comparing against the first.
PAGE_URLS = {
    store.MARKETING_URL: "index.html",
    store.PRIVACY_URL: "privacy.html",
    store.TERMS_URL: "terms.html",
    store.SUPPORT_URL: "support.html",
}


@check("the pages the listing and the app link are the pages that exist")
def urls():
    """Every URL this product hands a user, against the files and against each other.

    The half that was missing here cost a rejection risk nobody spotted for eight builds: this
    checked `store.py` against `docs/`, and never once looked at the URLs *compiled into the app*.
    They had drifted to a username that does not exist and a path with no extension, so the legal
    links in Settings answered 404 while every check in this file passed. Nothing is for sale now,
    so 3.1.2 no longer applies, but the privacy policy is still Apple's and the user's to read, and
    a 404 there is a 5.1.1 rejection instead of a 3.1.2 one.

    So the source of truth is `store.py`, and both the pages and the Swift have to agree with it.
    """
    problems = []
    expected = PAGE_URLS
    for url, filename in expected.items():
        path = ROOT / "docs" / filename
        if not path.exists():
            problems.append(f"{url} has no file at docs/{filename}")
            continue
        if filename != "index.html" and not url.endswith(filename):
            problems.append(f"{url} does not end in {filename}")
        sheets = read(path).count('<div class="sheet"')
        if sheets != len(LOCALES):
            problems.append(f"docs/{filename} carries {sheets} languages, expected {len(LOCALES)}")

    # Every https link the app compiles in, wherever it lives, checked against the listing's own
    # URLs. There is no exemption list any more: with the purchase screen gone, the only links left
    # in the binary are the two Settings rows, and both are pages in `docs/`.
    allowed = set(expected)
    pattern = re.compile(r'URL\(string:\s*"(https://[^"]+)"')
    for source in sorted((ROOT / "Sources").rglob("*.swift")):
        for url in pattern.findall(read(source)):
            if url not in allowed:
                problems.append(f"{source.relative_to(ROOT)} links {url}, which is not a listing URL")

    # The support address is filed with Apple in one place and typed into the app in another.
    contact = read(ROOT / "metadata" / "review_information" / "email_address.txt").strip()
    mailto = re.compile(r'URL\(string:\s*"mailto:([^"?]+)')
    for source in sorted((ROOT / "Sources").rglob("*.swift")):
        for address in mailto.findall(read(source)):
            if address != contact:
                problems.append(
                    f"{source.relative_to(ROOT)} writes to {address}, "
                    f"but review contact is {contact}"
                )

    if not (ROOT / "docs" / ".nojekyll").exists():
        problems.append("docs/.nojekyll is missing")
    return f"{len(expected)} pages, and every link in the app points at one", problems


@check("the live pages are the pages in this repository", testflight=False)
def urls_live():
    """The same URLs, fetched, and compared byte for byte with `docs/`.

    Files on disk prove nothing about what a reviewer's browser gets: the pages are served from S3
    behind CloudFront by `infra/`, the domain is delegated from a registrar by hand, and a
    certificate that has not validated yet looks exactly like a working site in a diff. `.app` is
    HSTS-preloaded, so there is no http fallback to be forgiving about either.

    The byte comparison is the half this check was missing, and what it missed was not subtle. On
    2026-09-03 the app had been stripped of every purchase, `docs/` had been regenerated to say so,
    and all four URLs answered 200 with our own markup, so this check was green — while the live
    site, last deployed a week earlier, still described a Dawnbreak Pro subscription, a restore
    button and a refund policy, in twelve languages, on the exact pages the App Store description
    links. A reviewer would have opened a subscription EULA for an app with nothing to buy. The
    pages are a CDK asset, so a fresh `docs/` reaches nobody until `npx cdk deploy DawnbreakSite`
    copies it up and invalidates the edge; a 200 only proves the *old* deploy is still healthy.

    Review-only, because a TestFlight build does not need the site up; a submission does.
    """
    import urllib.error
    import urllib.request

    problems = []
    for url, filename in PAGE_URLS.items():
        local = ROOT / "docs" / filename
        request = urllib.request.Request(url, method="GET", headers={"User-Agent": "dawnbreak-preflight"})
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                if response.status != 200:
                    problems.append(f"{url} answered {response.status}")
                    continue
                served = response.read(2_000_000)
        except urllib.error.HTTPError as error:
            problems.append(f"{url} answered {error.code}")
            continue
        except Exception as error:  # noqa: BLE001 - a DNS or TLS failure reads the same to a reviewer
            problems.append(f"{url} could not be fetched: {error}")
            continue

        if b'<div class="sheet"' not in served:
            problems.append(f"{url} answered 200 but is not one of our pages")
        elif not local.exists():
            problems.append(f"{url} is live but there is no docs/{filename} to compare it with")
        elif served != local.read_bytes():
            problems.append(
                f"{url} is not docs/{filename}: the live site is a stale deploy, "
                f"run `npx cdk deploy DawnbreakSite` from infra/")
    return f"{len(PAGE_URLS)} URLs, all 200 and byte-identical to docs/", problems


@check("the screenshots are complete and uploadable", testflight=False)
def screenshots():
    """Twelve folders, the same shots in each, at the one size the store still asks for.

    The alpha check is not pedantry: a compositor writes RGBA unless told otherwise, and App Store
    Connect rejects a screenshot with an alpha channel without saying which one.
    """
    from PIL import Image

    if not FRAMED.exists():
        return "not taken", ["build/shots/framed is missing, run scripts/shots.sh"]

    problems = []
    expected, error = generated(make_metadata.contract_locales)
    if error:
        return "unreadable", [error]

    counts = {}
    for locale in expected:
        folder = FRAMED / locale
        if not folder.is_dir():
            problems.append(f"no screenshots for {locale}, run scripts/shots.sh {locale}")
            continue
        shots = sorted(folder.glob("*.png"))
        counts[locale] = len(shots)
        if not 3 <= len(shots) <= 10:
            problems.append(f"{locale} has {len(shots)} screenshots, Apple takes 3 to 10")
        for path in shots:
            with Image.open(path) as image:
                if image.size != SHOT_SIZE:
                    problems.append(f"{locale}/{path.name} is {image.size[0]}×{image.size[1]}, "
                                    f"must be {SHOT_SIZE[0]}×{SHOT_SIZE[1]}")
                if "A" in image.mode:
                    problems.append(f"{locale}/{path.name} has an alpha channel")

    if len(set(counts.values())) > 1:
        problems.append(f"the languages disagree on how many screenshots there are: {counts}")
    return (f"{len(counts)} languages × {min(counts.values(), default=0)} shots at "
            f"{SHOT_SIZE[0]}×{SHOT_SIZE[1]}"), problems


# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Checks this repo against what App Store Connect accepts, without asking it."
    )
    parser.add_argument("--testflight", action="store_true",
                        help="only the checks that block a TestFlight upload")
    arguments = parser.parse_args()

    print(f"Preflight for {'TestFlight' if arguments.testflight else 'App Store review'}\n")

    failed, skipped, ran = 0, 0, 0
    for title, blocks_testflight, function in CHECKS:
        if arguments.testflight and not blocks_testflight:
            skipped += 1
            continue
        ran += 1
        detail, problems = function()
        if problems:
            failed += 1
            print(f"  ✗ {title}")
            for problem in problems:
                for line in str(problem).splitlines():
                    print(f"      {line}")
        else:
            print(f"  ✓ {title:<50} {detail}")

    print()
    if skipped:
        print(f"{skipped} review-only checks skipped.")
    if failed:
        print(f"{failed} of {ran} checks failed. Not ready to upload.")
        return 1
    print(f"All {ran} checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
