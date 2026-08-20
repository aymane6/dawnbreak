#!/usr/bin/env python3
"""Writes metadata/ — the App Store listing text for all twelve locales.

Run from the repo root: `python3 scripts/make_metadata.py`.

Output is fastlane `deliver`'s layout, because it is the one every upload tool and every reviewer
already recognises:

    metadata/en-US/name.txt              metadata/copyright.txt
    metadata/en-US/subtitle.txt          metadata/primary_category.txt
    metadata/en-US/keywords.txt          metadata/review_information/notes.txt
    metadata/en-US/description.txt       …
    metadata/en-US/promotional_text.txt
    metadata/en-US/release_notes.txt
    metadata/en-US/{support,privacy,marketing}_url.txt

One file per field rather than one JSON blob, because that is what the tooling reads and because a
diff on `metadata/de-DE/description.txt` is legible in a way a diff inside a JSON string is not.

Why generated at all, when the output is just text files: the twelve locales have to stay in step
with `CaptureLocale`, and every value has to stay under an App Store Connect limit. Both of those
are checks, and a check that is not run is a rejection two weeks later. Running this script is
also how the folder names come out as `pt-BR` rather than `pt_BR`, which is the difference between
an accepted upload and a rejected one.

The script fails rather than writing a listing App Store Connect will refuse when:

  * a value is over its character limit (counted in characters, as Apple counts them),
  * a locale is missing from a table, or a table has a locale the app does not ship,
  * the keywords field has a space after a comma, a duplicate term, or a term already indexed
    from the name or subtitle,
  * a description does not link the privacy policy and the support page (guideline 3.1.2),
  * the number of missions the copy promises is not the number `MissionKind` declares,
  * a description opens with more than 400 characters, which is past the fold nobody taps.
"""

from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from strings import store

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "metadata"

# The App Store Connect locale codes, read out of the Swift contract so this script cannot drift
# from the screenshot run. `CaptureLocale` is the one list of languages this project has.
CONTRACT = ROOT / "Sources" / "Contract" / "CaptureLocale.swift"

# The missions, for the same reason: the descriptions promise a number and the enum decides it.
MISSIONS = ROOT / "DawnbreakKit" / "Sources" / "DawnbreakKit" / "Models" / "MissionKind.swift"

# Set once in App Store Connect and not per locale.
PRIMARY_CATEGORY = "PRODUCTIVITY"
SECONDARY_CATEGORY = "HEALTH_AND_FITNESS"

# What a reviewer reads before they open the app. It exists because this app's central feature is
# invisible from a cold launch: an alarm that comes back is not something you can see in ninety
# seconds of tapping, and a reviewer who cannot find the feature rejects the build for not having
# it. So the note says exactly which buttons to press.
REVIEW_NOTES = """Dawnbreak is an alarm clock that will not switch off until a task is completed.

No account, no login, no server. Everything is stored on the device. There is nothing to give you
credentials for.

HOW TO SEE THE MAIN FEATURE IN UNDER A MINUTE

1. Open the app and allow the alarm permission when asked (AlarmKit).
2. Tap + and set the alarm one or two minutes ahead.
3. Under Mission, pick "Math" and leave the difficulty at Easy. Save.
4. Lock the phone and wait. The alarm rings on the lock screen through AlarmKit.
5. Press the second button on the alert (it is labelled with the mission, not "Open"). The app
   opens on the mission and the alarm is only silenced once the sum is answered.
6. To see the follow-up: press "Stop" instead. The alarm returns five minutes later under the
   title "Mission not done".

PERMISSIONS, AND WHY

- Alarms (AlarmKit): the whole app. Without it there is no alarm.
- Camera: only for the three missions that use it (photograph an object, scan a barcode, count
  squats). The frames are analysed on the device and never stored or transmitted.
- Motion and fitness: only for the step and shake missions. Read live, never written down.

There is no location, contacts, microphone, health, or tracking access of any kind, and no
analytics SDK.

IN-APP PURCHASES

Three, all unlocking the same "Pro" entitlement: monthly and yearly auto-renewable subscriptions
and a non-consumable lifetime purchase. Free gives one alarm, one round, three missions and
difficulty up to medium; Pro gives twenty-five alarms, ten rounds, twelve missions, four
difficulties and ninety days of history. The paywall states this, and Restore Purchases is on it.

An emergency exit is available in Settings and is on by default, so no alarm can trap a user.
"""

# Apple writes to this when a review stalls, so every value here is one a person answers. The
# surname is the account holder's as the distribution certificate spells it ("Apple Distribution:
# Aymane BAMHAMED"), not a guess.
CONTACT = {
    "first_name": "Aymane",
    "last_name": "Bamhamed",
    "phone_number": "+33671518425",
    "email_address": "fastpapershot.supp@outlook.com",
    "demo_account_required": "false",
}


def fail(message: str):
    sys.exit(f"make_metadata: {message}")


def contract_locales() -> list[str]:
    """The `store:` codes from CaptureLocale.swift, in declaration order.

    Parsed out of the Swift rather than repeated here: a thirteenth language is then one row in one
    file, and a language added to the app but not to the listing is impossible rather than merely
    unlikely.
    """
    source = CONTRACT.read_text(encoding="utf-8")
    order = re.findall(r'static let \w+ = CaptureLocale\(.*?store: "([^"]+)"\)', source)
    if not order:
        fail(f"no CaptureLocale rows found in {CONTRACT.relative_to(ROOT)}")
    return order


def check_mission_count():
    """What the twelve descriptions promise, against what `MissionKind` actually declares.

    Sliced at the nested `Capability` enum, whose cases are comma-separated on one line and are not
    missions. Everything above it is one case per line, which is the shape this counts.
    """
    source = MISSIONS.read_text(encoding="utf-8")
    _, _, body = source.partition("public enum MissionKind")
    body, _, _ = body.partition("public enum Capability")
    declared = len(re.findall(r"^\s+case [a-z]\w*\s*(?://.*)?$", body, re.MULTILINE))
    if declared == 0:
        fail(f"no mission cases found in {MISSIONS.relative_to(ROOT)}")
    if declared != store.MISSION_COUNT:
        fail(
            f"MissionKind declares {declared} missions, the listings promise {store.MISSION_COUNT}: "
            f"update store.MISSION_COUNT, MISSION_COUNT_WORD and all twelve descriptions"
        )


def check_coverage(locales: list[str]):
    expected = set(locales)
    for name, table, _ in store.FIELDS:
        missing = expected - set(table)
        extra = set(table) - expected
        if missing:
            fail(f"{name}: no value for {sorted(missing)}")
        if extra:
            fail(f"{name}: {sorted(extra)} is not a language this app ships")


def check_lengths(locales: list[str]):
    """Character counts, as App Store Connect counts them.

    Counted in characters and not bytes, which is why this is `len()` on a `str`: Apple's limit of
    30 for a name is 30 characters, so a Japanese name has 30 to work with and a German one has the
    same 30 despite being three times the bytes.
    """
    problems = []
    for name, table, limit in store.FIELDS:
        for locale in locales:
            value = table[locale]
            if not value.strip():
                problems.append(f"{locale}/{name} is empty")
            if len(value) > limit:
                problems.append(f"{locale}/{name}: {len(value)} characters, limit {limit}")
    if problems:
        fail("over the App Store limits:\n  " + "\n  ".join(problems))


def check_keywords(locales: list[str]):
    """The hundred characters that decide whether anyone finds the app.

    Three things waste them and none of them fail anywhere else: a space after a comma (Apple
    ignores it and still counts it), a term repeated in another form, and a term already in the
    name or subtitle, which is indexed separately.
    """
    problems = []
    for locale in locales:
        raw = store.KEYWORDS[locale]
        if ", " in raw:
            problems.append(f"{locale}: a space after a comma costs a character and buys nothing")

        terms = [term.strip() for term in raw.split(",")]
        if any(not term for term in terms):
            problems.append(f"{locale}: an empty keyword")

        lowered = [term.lower() for term in terms]
        duplicates = {term for term in lowered if lowered.count(term) > 1}
        if duplicates:
            problems.append(f"{locale}: repeated keyword {sorted(duplicates)}")

        # Already indexed from the name and subtitle, so a keyword repeating one of those words is
        # a hundredth of the field spent twice.
        indexed = set(
            re.findall(r"\w+", (store.NAME[locale] + " " + store.SUBTITLE[locale]).lower())
        ) - {"dawnbreak"}
        wasted = [term for term in lowered if term in indexed]
        if wasted:
            problems.append(f"{locale}: {wasted} is already in the name or subtitle")
    if problems:
        fail("keywords:\n  " + "\n  ".join(problems))


def check_descriptions(locales: list[str]):
    """Two things Apple rejects listings for, and one thing readers punish them for."""
    problems = []
    for locale in locales:
        description = store.DESCRIPTION[locale]

        # Guideline 3.1.2: a listing offering an auto-renewable subscription has to say what the
        # free tier gives and link a privacy policy. Both are checked by the reviewer by eye, and
        # the rejection costs a review cycle.
        if store.PRIVACY_URL not in description:
            problems.append(f"{locale}/description does not link the privacy policy")
        if store.SUPPORT_URL not in description:
            problems.append(f"{locale}/description does not link the support page")

        # The mission count, in this language's own words. A listing that promises twelve missions
        # while the binary ships nine is a rejection on 2.3.1, and this is the one claim in the copy
        # a reviewer can check in thirty seconds.
        word = store.MISSION_COUNT_WORD.get(locale)
        if word is None:
            problems.append(f"{locale}: no spelling of the mission count")
        elif word not in description:
            problems.append(f"{locale}/description never says {word} missions")

        # The App Store collapses the description after roughly three lines. If the first paragraph
        # does not say what the app is, nothing does.
        opening = description.split("\n\n", 1)[0]
        if len(opening) > 400:
            problems.append(f"{locale}/description opens with {len(opening)} characters before the fold")

        if "  " in description.replace("\n", ""):
            problems.append(f"{locale}/description has a double space")
        if description != description.strip():
            problems.append(f"{locale}/description has leading or trailing whitespace")
    if problems:
        fail("descriptions:\n  " + "\n  ".join(problems))


def write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    # A single trailing newline and nothing else: `deliver` uploads the file's contents verbatim,
    # so a stray blank line becomes a blank line in the listing.
    path.write_text(text.rstrip("\n") + "\n", encoding="utf-8")


def main():
    locales = contract_locales()
    check_mission_count()
    check_coverage(locales)
    check_lengths(locales)
    check_keywords(locales)
    check_descriptions(locales)

    # Rewritten from scratch, because a locale removed from the tables has to disappear from the
    # folder too: a stale `metadata/tr/` would be uploaded as a Turkish listing nobody wrote.
    if OUT.exists():
        shutil.rmtree(OUT)

    for locale in locales:
        folder = OUT / locale
        for name, table, _ in store.FIELDS:
            write(folder / f"{name}.txt", table[locale])
        for name, value in store.SHARED:
            write(folder / f"{name}.txt", value)

    write(OUT / "copyright.txt", store.COPYRIGHT)
    write(OUT / "primary_category.txt", PRIMARY_CATEGORY)
    write(OUT / "secondary_category.txt", SECONDARY_CATEGORY)
    write(OUT / "review_information" / "notes.txt", REVIEW_NOTES)
    for name, value in CONTACT.items():
        write(OUT / "review_information" / f"{name}.txt", value)

    print(f"metadata/: {len(locales)} locales × {len(store.FIELDS)} fields")
    for name, table, limit in store.FIELDS:
        longest = max(locales, key=lambda locale: len(table[locale]))
        print(f"  {name:<18} longest {len(table[longest]):>4} / {limit} ({longest})")


if __name__ == "__main__":
    main()
