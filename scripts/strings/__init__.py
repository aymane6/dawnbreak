"""Translation tables for Dawnbreak's String Catalogs.

Why tables in Python rather than twelve hand-edited .xcstrings files: a fifth of this app's
keys are derived at runtime (`mission.\\(kind).title`, `typing.sentence.\\(band).\\(index)`),
so Xcode's extractor never sees them and cannot create them. Anything the extractor cannot
create has to be written by hand into a 12-locale JSON blob, and hand-editing that blob is how
a locale ends up silently missing forty keys.

So the source of truth is here, one row per key with the twelve values in a fixed order, and
`make_strings.py` expands it. The same script cross-checks the rows against the keys actually
used in the Swift sources, in both directions, so a key added to a view without a translation
fails the build rather than shipping as a raw dotted string on someone's lock screen.

Order matters and is checked: every row must have exactly `len(LOCALES)` entries.
"""

# `en` first because it is the development language and the fallback; the rest alphabetical.
# This order is the row order in every table below. Do not reorder without regenerating.
LOCALES = [
    "en",
    "ar",
    "de",
    "es",
    "fr",
    "hi",
    "it",
    "ja",
    "ko",
    "pt-BR",
    "ru",
    "zh-Hans",
]

SOURCE_LANGUAGE = "en"

# Right-to-left locales, exported for the screenshot compositor: it has to mirror its layout,
# not just swap the font.
RTL_LOCALES = {"ar"}

#: Plural categories each locale actually distinguishes, per CLDR. Only consulted for the
#: handful of keys that carry `variations.plural`; everything else is phrased to avoid plurals
#: because a count-agnostic sentence is translatable by anyone and a plural rule is not.
PLURAL_CATEGORIES = {
    "en": ("one", "other"),
    "ar": ("zero", "one", "two", "few", "many", "other"),
    "de": ("one", "other"),
    "es": ("one", "many", "other"),
    "fr": ("one", "many", "other"),
    "hi": ("one", "other"),
    "it": ("one", "many", "other"),
    "ja": ("other",),
    "ko": ("other",),
    "pt-BR": ("one", "many", "other"),
    "ru": ("one", "few", "many", "other"),
    "zh-Hans": ("other",),
}


def rows(*tables):
    """Merges the per-area tables, refusing to let two of them define the same key.

    A duplicate key is always a mistake here: the later table would silently win, and the
    losing translation would look present in review and be absent at runtime.
    """
    merged = {}
    for table in tables:
        for key, values in table.items():
            if key in merged:
                raise SystemExit(f"duplicate key across tables: {key}")
            if len(values) != len(LOCALES):
                raise SystemExit(
                    f"{key}: {len(values)} values, expected {len(LOCALES)}"
                )
            merged[key] = list(values)
    return merged


def family(prefix, suffix, cases):
    """Expands an enum-derived family: `family("mission.", ".title", {...})`.

    The `cases` dict is keyed by the Swift enum's raw value, so a case renamed in Swift and not
    here shows up as a missing key rather than as a wrong translation.
    """
    return {f"{prefix}{case}{suffix}": values for case, values in cases.items()}
