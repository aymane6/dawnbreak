#!/usr/bin/env python3
"""Writes docs/ — the three pages App Store Connect wants URLs for.

Run from the repo root: `python3 scripts/make_pages.py`.

    docs/index.html      the marketing URL
    docs/privacy.html    the privacy policy URL, which Apple requires before submission
    docs/support.html    the support URL, which Apple also requires

Served by GitHub Pages from this folder, which is why the output is three plain files with no build
step, no dependencies and no JavaScript that the page needs in order to say anything.

Each file carries all twelve translations. One URL per subject rather than twelve, because the
twelve descriptions in `store.py` quote these URLs inside their text: a per-language URL would mean
the same link written twelve times in twelve places, and a dead link in eleven of them the day one
is renamed. English is in the markup; a reader whose browser asks for another language gets it
swapped in on load, and can override with the picker or with `?lang=ja`.

The pages fail to generate rather than ship wrong when:

  * a language is missing a page, or has one English does not have,
  * a page's block structure differs from English (a missing heading, an extra paragraph),
  * the URLs in `store.py` do not point at the files this script writes.
"""

from __future__ import annotations

import html
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from strings import LOCALES, RTL_LOCALES, SOURCE_LANGUAGE, pages, store

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs"

# Where to send someone who has an actual problem. A repository issue rather than an email address,
# because it is a channel that exists and works today, and a support page whose contact link bounces
# is worse than one with no contact link at all.
ISSUES_URL = "https://github.com/aymane6/dawnbreak/issues"

# The palette, from Palette in scripts/frame-shots.swift and the app's own asset catalogue. Repeated
# here rather than shared because a stylesheet and a Swift enum cannot import each other, and three
# colours are cheaper to keep in step than a build step that generates CSS.
CSS = """:root {
  color-scheme: dark;
  --canvas: #0b0d14;
  --canvas-top: #1a1526;
  --ink: #f6f4f1;
  --ink-dim: #9ba0b5;
  --hairline: #2c3145;
  --dawn-start: #ffa24b;
  --dawn-end: #ff5e62;
}

* { box-sizing: border-box; }

html { -webkit-text-size-adjust: 100%; }

body {
  margin: 0;
  padding: 0 1.25rem 5rem;
  background:
    radial-gradient(120% 60% at 50% 0%, var(--canvas-top) 0%, transparent 60%),
    var(--canvas);
  color: var(--ink);
  font: 400 1.0625rem/1.65 ui-rounded, "SF Pro Rounded", -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
  text-wrap: pretty;
}

.sheet { max-width: 36rem; margin: 0 auto; }

header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 1rem;
  padding: 1.75rem 0 0;
  border-bottom: 1px solid var(--hairline);
  margin-bottom: 2.5rem;
}

/* The wordmark, which is the app's name and is never translated. */
.mark {
  font-size: 1.0625rem;
  font-weight: 600;
  letter-spacing: 0.01em;
  text-decoration: none;
  color: var(--ink);
  padding-bottom: 1.25rem;
}

.mark span {
  background: linear-gradient(100deg, var(--dawn-start), var(--dawn-end));
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

/* A real select element, so it is reachable by keyboard and by VoiceOver without any work. */
select {
  appearance: none;
  margin-bottom: 1.25rem;
  padding: 0.35rem 1.9rem 0.35rem 0.7rem;
  border: 1px solid var(--hairline);
  border-radius: 0.6rem;
  background: transparent;
  background-image: linear-gradient(45deg, transparent 50%, var(--ink-dim) 50%), linear-gradient(135deg, var(--ink-dim) 50%, transparent 50%);
  background-position: right 0.85rem center, right 0.6rem center;
  background-size: 0.3rem 0.3rem, 0.3rem 0.3rem;
  background-repeat: no-repeat;
  color: var(--ink-dim);
  font: inherit;
  font-size: 0.9375rem;
}

select:focus-visible, a:focus-visible {
  outline: 2px solid var(--dawn-start);
  outline-offset: 3px;
}

h1 {
  margin: 0 0 0.5rem;
  font-size: clamp(2.25rem, 9vw, 3.25rem);
  font-weight: 700;
  line-height: 1.05;
  letter-spacing: -0.02em;
}

.tagline {
  margin: 0 0 2.5rem;
  font-size: 1.25rem;
  line-height: 1.4;
  color: var(--ink-dim);
}

h2 {
  margin: 2.75rem 0 0.75rem;
  font-size: 1.0625rem;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--dawn-start);
}

/* Uppercasing a Japanese or Arabic heading does nothing and letter-spacing it does harm. */
html:lang(ar) h2, html:lang(hi) h2, html:lang(ja) h2, html:lang(ko) h2, html:lang(zh-Hans) h2 {
  text-transform: none;
  letter-spacing: 0;
}

p { margin: 0 0 1.1rem; }

ul { margin: 0 0 1.1rem; padding-inline-start: 1.1rem; }

li { margin-bottom: 0.55rem; }

a { color: var(--dawn-start); text-decoration-thickness: 1px; text-underline-offset: 0.2em; }

footer {
  margin-top: 3.5rem;
  padding-top: 1.5rem;
  border-top: 1px solid var(--hairline);
  color: var(--ink-dim);
  font-size: 0.9375rem;
}

footer a { color: var(--ink-dim); }

footer nav { display: flex; flex-wrap: wrap; gap: 1.25rem; margin-bottom: 0.75rem; }

/* One language at a time. Eleven of the twelve sheets carry `hidden` in the markup, so a reader
   with no JavaScript gets English rather than twelve copies of everything; the script moves the
   attribute rather than adding a class, and this is what makes it bite. */
.sheet[hidden] { display: none; }
"""

# Picks the reader's language before first paint. Inline and tiny, and the page is complete without
# it: every sheet is in the HTML, and hiding all but one is the only thing this does.
SCRIPT = """(function () {
  var sheets = document.querySelectorAll('.sheet');
  var available = {};
  for (var i = 0; i < sheets.length; i++) available[sheets[i].lang] = sheets[i];

  function pick() {
    var asked = new URLSearchParams(location.search).get('lang');
    var wanted = asked ? [asked] : (navigator.languages || [navigator.language || 'en']);
    for (var i = 0; i < wanted.length; i++) {
      var tag = wanted[i];
      if (available[tag]) return tag;
      // 'pt-PT' should land on 'pt-BR', and 'zh-CN' on 'zh-Hans': try the base language, then any
      // sheet that starts with it, before falling through to English.
      var base = tag.split('-')[0];
      if (available[base]) return base;
      for (var code in available) if (code.split('-')[0] === base) return code;
    }
    return 'en';
  }

  function show(code) {
    for (var tag in available) available[tag].hidden = tag !== code;
    document.documentElement.lang = code;
    document.documentElement.dir = available[code].dir || 'ltr';
    document.title = available[code].dataset.title;
    var picker = available[code].querySelector('select');
    if (picker) picker.value = code;
  }

  show(pick());

  document.addEventListener('change', function (event) {
    if (event.target.matches('select[data-picker]')) show(event.target.value);
  });
})();"""


def fail(message: str):
    sys.exit(f"make_pages: {message}")


def check_shape():
    """Every language has every page, with the same blocks in the same order as English.

    The shape is the check that matters: a translator who drops a heading produces a page that reads
    as a wall of text and fails nothing, and a translator who drops a whole block produces a page
    that is quietly missing the paragraph about the camera.
    """
    problems = []
    for name, table in pages.PAGES.items():
        missing = set(LOCALES) - set(table)
        extra = set(table) - set(LOCALES)
        if missing:
            problems.append(f"{name}: no {sorted(missing)}")
        if extra:
            problems.append(f"{name}: {sorted(extra)} is not a language this app ships")

        shape = [kind for kind, _ in table[SOURCE_LANGUAGE]]
        for language in table:
            mine = [kind for kind, _ in table[language]]
            if mine != shape:
                problems.append(f"{name}/{language}: blocks are {mine}, English has {shape}")

        for language in LOCALES:
            if not pages.TITLE[name].get(language, "").strip():
                problems.append(f"{name}: no title for {language}")

    for language in LOCALES:
        if not pages.TAGLINE.get(language, "").strip():
            problems.append(f"no tagline for {language}")
        if not pages.LANGUAGE_NAME.get(language, "").strip():
            problems.append(f"nothing for the picker to call {language}")

    if problems:
        fail("page structure:\n  " + "\n  ".join(problems))


def check_urls():
    """The URLs in the listing copy have to be the files this script actually writes.

    `store.py` bakes them into twelve descriptions and into `metadata/*/privacy_url.txt`. A rename
    here without a rename there is a privacy policy URL that 404s, which is a rejection.
    """
    expected = {
        "index.html": store.MARKETING_URL,
        "privacy.html": store.PRIVACY_URL,
        "support.html": store.SUPPORT_URL,
    }
    problems = []
    for filename, url in expected.items():
        tail = url.rstrip("/").rsplit("/", 1)[-1]
        # The marketing URL is the folder itself, which GitHub Pages serves as index.html.
        if filename == "index.html":
            if not url.endswith("/"):
                problems.append(f"MARKETING_URL should end in a slash: {url}")
        elif tail != filename:
            problems.append(f"{url} does not point at docs/{filename}")
    if problems:
        fail("urls:\n  " + "\n  ".join(problems))


def markup(text: str) -> str:
    """Escapes the copy, then puts back the one tag the copy is allowed to contain.

    Escape first and selectively unescape after, rather than trusting the tables: the tables hold
    prose in twelve languages and an unescaped `&` in one of them would break the page silently.
    """
    escaped = html.escape(text, quote=False)
    escaped = re.sub(
        r"&lt;a href=&quot;([^&]+)&quot;&gt;(.*?)&lt;/a&gt;",
        r'<a href="\1">\2</a>',
        escaped,
    )
    return escaped


def blocks_html(blocks, indent: str) -> str:
    out = []
    for kind, payload in blocks:
        if kind == "h":
            out.append(f"{indent}<h2>{markup(payload)}</h2>")
        elif kind == "p":
            out.append(f"{indent}<p>{markup(payload)}</p>")
        elif kind == "ul":
            items = "\n".join(f"{indent}  <li>{markup(item)}</li>" for item in payload)
            out.append(f"{indent}<ul>\n{items}\n{indent}</ul>")
        else:
            fail(f"unknown block {kind!r}")
    return "\n".join(out)


def picker_html(current: str, indent: str) -> str:
    options = "\n".join(
        f'{indent}    <option value="{code}"{" selected" if code == current else ""}>'
        f"{html.escape(pages.LANGUAGE_NAME[code])}</option>"
        for code in LOCALES
    )
    # `aria-label` rather than a visible label: the control shows the language it is set to, which
    # is the whole label a sighted reader needs, and a screen reader still hears what it is for.
    return (
        f'{indent}  <select data-picker aria-label="{html.escape(pages.LANGUAGE_NAME[current])}">\n'
        f"{options}\n"
        f"{indent}  </select>"
    )


def footer_html(page: str, language: str, indent: str) -> str:
    """The other two pages, plus the copyright. Named in the reader's language, not in English."""
    links = []
    for other in ("index", "privacy", "support"):
        if other == page:
            continue
        target = "./" if other == "index" else f"{other}.html"
        links.append(f'{indent}    <a href="{target}">{html.escape(pages.TITLE[other][language])}</a>')
    # Left as "GitHub" in every language, because that is the name of the place the link goes and
    # nobody looks for a translation of it.
    links.append(f'{indent}    <a href="{ISSUES_URL}">GitHub</a>')
    # `dir="ltr"` on the copyright, which is the same eleven Latin characters in all twelve
    # languages. Without it the Arabic page renders it as "Aymane Bammou 2026 ©": bidi reorders a
    # left-to-right run inside a right-to-left paragraph by putting its neutral characters, the sign
    # and the year, on the other side. The span pins the run instead of relying on the paragraph.
    return (
        f"{indent}<footer>\n"
        f"{indent}  <nav>\n" + "\n".join(links) + f"\n{indent}  </nav>\n"
        f'{indent}  <p><span dir="ltr">&copy; {html.escape(store.COPYRIGHT)}</span></p>\n'
        f"{indent}</footer>"
    )


def sheet_html(page: str, language: str) -> str:
    heading = pages.TITLE[page][language]
    tagline = pages.TAGLINE[language] if page == "index" else ""
    direction = "rtl" if language in RTL_LOCALES else "ltr"

    # The tab title, which the script swaps in with the sheet. The marketing page is called
    # "Dawnbreak" in all twelve languages, so pairing it with itself would read "Dawnbreak ·
    # Dawnbreak"; there it takes the tagline instead.
    title = f"Dawnbreak · {tagline.rstrip('.｡。')}" if page == "index" else f"{heading} · Dawnbreak"

    parts = [
        f'    <div class="sheet" lang="{language}" dir="{direction}"'
        f' data-title="{html.escape(title)}" hidden>',
        "      <header>",
        f'        <a class="mark" href="./">Dawn<span>break</span></a>',
        picker_html(language, "      "),
        "      </header>",
        "      <main>",
        f"        <h1>{markup(heading)}</h1>",
    ]
    if tagline:
        parts.append(f'        <p class="tagline">{markup(tagline)}</p>')
    parts.append(blocks_html(pages.PAGES[page][language], "        "))
    parts.append("      </main>")
    parts.append(footer_html(page, language, "      "))
    parts.append("    </div>")
    return "\n".join(parts)


def page_html(page: str) -> str:
    # English is not `hidden`, so a reader with JavaScript off gets a complete page in the language
    # every other language falls back to anyway.
    sheets = []
    for language in LOCALES:
        sheet = sheet_html(page, language)
        if language == SOURCE_LANGUAGE:
            sheet = sheet.replace(' hidden>', ">", 1)
        sheets.append(sheet)

    title = f"{pages.TITLE[page][SOURCE_LANGUAGE]} · Dawnbreak"
    if page == "index":
        title = f"Dawnbreak · {pages.TAGLINE[SOURCE_LANGUAGE].rstrip('.')}"

    return f"""<!DOCTYPE html>
<html lang="en" dir="ltr">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="color-scheme" content="dark">
    <title>{html.escape(title)}</title>
    <meta name="description" content="{html.escape(pages.TAGLINE[SOURCE_LANGUAGE])}">
    <link rel="canonical" href="{store.MARKETING_URL if page == "index" else store.MARKETING_URL + page + ".html"}">
    <style>
{CSS}    </style>
  </head>
  <body>
{chr(10).join(sheets)}
    <script>
{SCRIPT}
    </script>
  </body>
</html>
"""


def main():
    check_shape()
    check_urls()

    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    # GitHub Pages runs Jekyll over the folder unless told not to, and Jekyll would take a `{{` in
    # any future copy as a template tag. Nothing here needs it.
    (OUT / ".nojekyll").write_text("", encoding="utf-8")

    for page in pages.PAGES:
        path = OUT / f"{page}.html"
        path.write_text(page_html(page), encoding="utf-8")
        print(f"  docs/{path.name:<14} {len(LOCALES)} languages, {path.stat().st_size // 1024} KB")

    print(f"docs/: {len(pages.PAGES)} pages")


if __name__ == "__main__":
    main()
