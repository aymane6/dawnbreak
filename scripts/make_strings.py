#!/usr/bin/env python3
"""Writes Resources/Localizable.xcstrings and Resources/InfoPlist.xcstrings.

Run from the repo root: `python3 scripts/make_strings.py`.

Why a generator rather than Xcode's extractor: about a fifth of this app's keys never appear as
a literal in the source. `MissionKind.titleKey` builds "mission.\\(rawValue).title",
`TypingChallenge` builds "typing.sentence.\\(band).\\(index)", `StatsView` builds
"stats.window.\\(rawValue)". Xcode's extractor cannot see any of those, so it cannot create
them, and a missing key renders as the key itself: a user in Osaka would read
"mission.squats.title" instead of a sentence. Generating from the same enum case lists is what
keeps the catalog and the code in step.

The script fails rather than writing a bad catalog when:

  * a dotted literal in Sources/ or Widget/ has no row in the tables (a key on screen raw),
  * a row exists that nothing can reach (a translation paid for and never shown),
  * a translation's format specifiers differ from the English ones (a crash, or a wrong number),
  * a plural row's categories are not exactly that locale's CLDR set,
  * an Arabic value types a number in Latin digits, which the Arabic interface never shows,
  * an InfoPlist value drifts from the fallback baked into project.yml.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from strings import LOCALES, PLURAL_CATEGORIES, SOURCE_LANGUAGE, rows
from strings import capture, content, core, infoplist, missions, paywall, plurals, screens

ROOT = Path(__file__).resolve().parent.parent
# The kit is scanned too: it holds no views, but `MissionKind`, `Difficulty` and
# `Preferences.Appearance` are where the derived keys are built, and a key it names is still a
# key the app puts on screen.
SCANNED = ("Sources", "Widget", "DawnbreakKit/Sources")

# Keys the app builds at runtime from an enum, with the code that builds them. A row whose key
# starts with one of these prefixes is considered reachable even though no literal spells it
# out. The generator checks each prefix is still used, so deleting a feature does not leave its
# translations behind.
DERIVED = {
    "mission.": 'MissionKind.titleKey / .subtitleKey / .instructionKey ("mission.\\(rawValue).…")',
    "difficulty.": "Difficulty.titleKey",
    "sound.": "AlarmSound.titleKey",
    "weekday.": "Weekday.titleKey and .shortKey",
    "appearance.": "Preferences.Appearance.titleKey",
    "outcome.": "WakeOutcome.titleKey",
    "typing.sentence.": "TypingChallenge.sentenceKey",
    "stats.window.": "StatsView.Window.titleKey",
    "draw.prompt.": "DrawingPrompt.titleKey",
    "paywall.plan.": "SubscriptionStore.Product.titleKey",
    "paywall.period.": "SubscriptionStore.periodKey(for:)",
    "paywall.reason.": "AppEnvironment.PaywallReason.headlineKey",
    "settings.permission.": "SettingsView.authorizationKey",
    "editor.title.": "AlarmEditorView.titleKey",
    "editor.enroll.": "AlarmEditorView.enrolmentKey",
    "enroll.": "EnrolmentView keys chosen by mission kind",
    "error.": "thrown-error copy chosen by case",
    "onboarding.": "OnboardingView page keys",
    "widget.subhead.": "NextAlarmWidget.subheadKey",
    "shot.caption.": "CaptureLaunch.Screen.captionKey",
    "shot.sub.": "CaptureLaunch.Screen.subcaptionKey",
}

# Dotted literals that are not localization keys. Every one of these is a real string the app
# needs; they are listed so that a *new* dotted literal fails the build instead of being
# silently assumed harmless.
NOT_KEYS = frozenset({
    # SF Symbols with dots in their names.
    "alarm.fill", "alarm.slash", "alarm.waves.left.and.right.fill", "barcode.viewfinder",
    "camera.viewfinder", "speaker.wave.3.fill",
    "checkmark.circle.fill", "checkmark.seal.fill", "chart.line.uptrend.xyaxis", "circle.fill",
    "circle.hexagongrid.fill", "diamond.fill", "exclamationmark.triangle.fill",
    "figure.strengthtraining.functional", "figure.strengthtraining.traditional", "flame.fill",
    "largecircle.fill.circle", "moon.zzz.fill", "pencil.and.scribble", "plus.viewfinder",
    "square.fill", "square.grid.3x3.fill", "stop.fill", "sunrise.fill", "triangle.fill",
    "xmark.circle.fill",
    # Filenames.
    "alarms.json",
})

# Prefixes that mark a literal as an identifier rather than a key: product IDs, the App Group,
# the widget kind, a dispatch queue label, the UserDefaults keys, which are deliberately shaped
# like the setting they hold, and the accessibility identifiers in `AccessibilityID`, which the UI
# tests navigate by and which must never be translated.
NOT_KEY_PREFIXES = ("com.aymbam.", "group.com.aymbam.", "pref.", "ax.")

KEY_SHAPE = re.compile(r"^[a-z][a-zA-Z0-9]*(?:\.[a-zA-Z0-9]+)+$")
LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
# An SF Symbol name, recognised by the argument it is passed to rather than by the line it is
# on: `FeatureRow(systemImage: "flame.fill", titleKey: "paywall.feature.difficulty", …)` puts a
# symbol and a key on the same line.
SYMBOL_ARGUMENT = re.compile(r"(?:systemName|systemImage)\s*:\s*$")
# A `var systemImage: String { switch self { … } }` returning bare symbol names. Skipping the
# whole property keeps this script from needing an entry per symbol as missions are added.
SYMBOL_PROPERTY = re.compile(r"\bvar\s+(?:systemImage|systemName)\s*:\s*String\b")
# `%1$lld`, `%lld`, `%@`, `%.1f` — but not the `%%` that renders a literal percent sign.
SPECIFIER = re.compile(r"%(?:(\d+)\$)?[-+ 0#]*\d*(?:\.\d+)?(?:l{0,2}[du]|@|f)")


def swift_files():
    for folder in SCANNED:
        yield from sorted((ROOT / folder).rglob("*.swift"))


def literal_keys():
    """Every dotted string literal in the app and widget targets, minus the ones that are not
    keys. Returns {key: "file:line"} so an error can point at the offending line."""
    found = {}
    unexpected = []
    for path in swift_files():
        in_symbols, depth = False, 0
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if not in_symbols and SYMBOL_PROPERTY.search(line):
                in_symbols, depth = True, 0
            if in_symbols:
                depth += line.count("{") - line.count("}")
                in_symbols = depth > 0
                continue
            for match in LITERAL.finditer(line):
                literal = match.group(1)
                if not KEY_SHAPE.match(literal):
                    continue
                if SYMBOL_ARGUMENT.search(line[:match.start()]):
                    continue
                if literal in NOT_KEYS or literal.startswith(NOT_KEY_PREFIXES):
                    continue
                where = f"{path.relative_to(ROOT)}:{number}"
                found.setdefault(literal, where)
                if literal.count(".") > 4:
                    unexpected.append(f"{where}: suspiciously deep key {literal!r}")
    if unexpected:
        fail("\n".join(unexpected))
    return found


def specifiers(value: str):
    """The ordered format specifiers in a value, as a comparable signature."""
    cleaned = value.replace("%%", "")
    return tuple(match.group(0) for match in SPECIFIER.finditer(cleaned))


def fail(message: str):
    sys.exit(f"make_strings: {message}")


def check_reachable(table, literals):
    """Rows must be either spelled out in the source or built by known code."""
    orphans = []
    for key in table:
        if key in literals:
            continue
        if any(key.startswith(prefix) for prefix in DERIVED):
            continue
        orphans.append(key)
    if orphans:
        fail("rows nothing can display, delete them or the code that lost them:\n  "
             + "\n  ".join(sorted(orphans)))

    used = set()
    for path in swift_files():
        text = path.read_text(encoding="utf-8")
        for prefix in DERIVED:
            if f'"{prefix}' in text:
                used.add(prefix)
    for prefix, built_by in sorted(DERIVED.items()):
        if prefix not in used:
            fail(f"no source builds {prefix!r} any more (was {built_by}); "
                 "drop it from DERIVED and delete its rows")


def check_missing(table, literals):
    absent = {key: where for key, where in literals.items() if key not in table}
    if absent:
        fail("keys used in the app with no translation, they would render raw:\n  "
             + "\n  ".join(f"{where}  {key}" for key, where in sorted(absent.items(), key=lambda item: item[1])))


def check_specifiers(table):
    """Same arguments, same types, in whatever order the language wants them.

    Compared as a sorted multiset, because Japanese writing "%2$@%1$@" for a clock is the whole
    point of positional specifiers. What must not differ is *which* arguments appear: a dropped
    `%2$lld` silently loses a number, and a `%@` where English has `%lld` crashes.
    """
    problems = []
    for key, values in table.items():
        english = sorted(specifiers(values[0]))
        for locale, value in zip(LOCALES, values):
            mine = sorted(specifiers(value))
            if mine != english:
                problems.append(f"{key} [{locale}]: {mine} vs en {english}")
            if len(english) > 1 and any("$" not in spec for spec in mine):
                problems.append(f"{key} [{locale}]: multi-argument values need %1$…, %2$… so a "
                                f"translation can reorder them")
    if problems:
        fail("format specifiers do not match:\n  " + "\n  ".join(problems))


def check_arabic_digits(table):
    """Arabic writes numbers in Arabic-Indic digits, so a translation must not type Latin ones.

    Everything the app formats itself comes out that way: `6:15 AM` renders as ٦:١٥ ص and every
    `%lld` is substituted with ٣٠, because that is what `ar_SA` does. A value that spells "30" by
    hand therefore puts ٣٠ and 30 on the same screen, which is the kind of detail that makes an
    interface read as machine-translated. Checked here rather than by eye, because it is invisible
    to anyone who does not read Arabic and the screenshots are the first place it shows up.
    """
    arabic = LOCALES.index("ar")
    problems = [
        f"{key}: {values[arabic]!r}"
        for key, values in table.items()
        # Specifiers dropped first: `%1$lld` carries digits that belong to the argument number,
        # and the number it substitutes is localized by the OS.
        if re.search(r"[0-9]", SPECIFIER.sub("", values[arabic].replace("%%", "")))
    ]
    if problems:
        fail("Arabic values with Latin digits, write them in ٠-٩:\n  " + "\n  ".join(problems))


def flat_entry(values):
    return {
        "extractionState": "manual",
        "localizations": {
            locale: {"stringUnit": {"state": "translated", "value": value}}
            for locale, value in zip(LOCALES, values)
        },
    }


def plural_entry(key, spec):
    """A substitution rather than a bare `variations.plural`, so `formatSpecifier` is declared
    and a variant may leave the numeral out: Arabic's dual is a word, not "2 يوم"."""
    name, arg, fmt, table = spec["name"], spec["arg"], spec["spec"], spec["rows"]
    if len(table) != len(LOCALES):
        fail(f"{key}: {len(table)} plural rows, expected {len(LOCALES)}")

    localizations = {}
    for locale, variants in zip(LOCALES, table):
        expected = set(PLURAL_CATEGORIES[locale])
        if set(variants) != expected:
            fail(f"{key} [{locale}]: categories {sorted(variants)}, "
                 f"CLDR wants {sorted(expected)}")
        localizations[locale] = {
            "stringUnit": {"state": "translated", "value": f"%#@{name}@"},
            "substitutions": {
                name: {
                    "argNum": arg,
                    "formatSpecifier": fmt,
                    "variations": {
                        "plural": {
                            category: {"stringUnit": {"state": "translated", "value": variants[category]}}
                            for category in PLURAL_CATEGORIES[locale]
                        }
                    },
                }
            },
        }
    return {"extractionState": "manual", "localizations": localizations}


def catalog(entries):
    return {
        "sourceLanguage": SOURCE_LANGUAGE,
        "strings": {key: entries[key] for key in sorted(entries)},
        "version": "1.0",
    }


def write(path: Path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    # Xcode's own formatting: 2-space indent, key order preserved, trailing newline.
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def check_infoplist_matches_project(table):
    """The English purpose strings are also baked into the built Info.plist as the fallback for
    an unlisted language. If the two drift, one language promises something the others do not."""
    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    for key, values in table.items():
        if f'{key}: "{values[0]}"' not in project:
            fail(f"{key}: the en value differs from the fallback in project.yml")


def build():
    """The two catalogues, checked, in memory.

    Separate from `main` so `asc-preflight.py` can ask whether what is on disk is what this
    script would write, without writing it: a submission built from a stale catalogue ships
    twelve languages of last week's copy.
    """
    literals = literal_keys()

    table = rows(
        core.CHROME, core.ERRORS, core.TIME, core.WEEKDAYS, core.WEEKDAYS_SHORT, core.REPEAT,
        core.DIFFICULTY, core.SOUNDS, core.APPEARANCE, core.OUTCOMES, core.ALARM, core.WIDGET,
        missions.TITLES, missions.SUBTITLES, missions.INSTRUCTIONS, missions.RUNNER,
        missions.MATH, missions.PATTERN, missions.TYPING_UI, missions.MOTION, missions.CAMERA,
        missions.DRAW_FLAP,
        content.SENTENCES, content.DRAW_PROMPTS, content.PREVIEWS,
        screens.ALARMS, screens.EDITOR, screens.ENROLL, screens.ONBOARDING, screens.SETTINGS,
        screens.STATS,
        paywall.PAYWALL, paywall.PLANS, paywall.PERIODS, paywall.REASONS,
        capture.LABELS, capture.CAPTIONS,
    )

    overlap = set(table) & set(plurals.PLURALS)
    if overlap:
        fail(f"defined both flat and plural: {sorted(overlap)}")

    everything = dict(table)
    everything.update({key: None for key in plurals.PLURALS})

    check_missing(everything, literals)
    check_reachable(everything, literals)
    check_specifiers(table)
    check_arabic_digits(table)

    entries = {key: flat_entry(values) for key, values in table.items()}
    for key, spec in plurals.PLURALS.items():
        entries[key] = plural_entry(key, spec)

    check_infoplist_matches_project(infoplist.USAGE)
    usage = {key: flat_entry(values) for key, values in infoplist.USAGE.items()}

    return catalog(entries), catalog(usage)


CATALOGUES = {
    "Resources/Localizable.xcstrings": 0,
    "Resources/InfoPlist.xcstrings": 1,
}


def main():
    built = build()
    for name, index in CATALOGUES.items():
        write(ROOT / name, built[index])

    strings, usage = built
    print(f"Localizable.xcstrings: {len(strings['strings'])} keys × {len(LOCALES)} locales "
          f"({len(plurals.PLURALS)} of them plural)")
    print(f"InfoPlist.xcstrings:   {len(usage['strings'])} keys × {len(LOCALES)} locales")


if __name__ == "__main__":
    main()
