#!/usr/bin/env python3
"""The App Store listing, from what is in `metadata/` and `build/shots/framed/`.

    python3 scripts/publish.py

Creates, or updates, and then reports:

    app info          name, subtitle and privacy policy URL in twelve languages, two categories
    version 1.0.0     copyright, manual release
    localizations     description, keywords, promotional text, release notes, three URLs, ×12
    screenshots       the six framed shots per language, into the 6.9-inch iPhone set
    review details    the contact Apple calls when a review stalls, and the notes
    age rating        the questionnaire, answered as an alarm clock with no objectionable content
    price             free, if no price schedule has been set yet

Everything is read from files rather than from the generators: `metadata/en-US/name.txt` is what
gets sent, so what Apple receives is what the repository shows in a diff. `scripts/make_metadata.py`
writes those files and `scripts/asc-preflight.py` checks they are current, which makes a stale
listing a preflight failure rather than a surprise on the store page.

It stops short of one thing on purpose: it does not submit anything for review. Submitting is
irreversible from a script's point of view, and it is not what "prepare the submission" means. The
last line prints what is left, which is a person clicking Submit once they have read the page.

    export ASC_KEY_ID=XXXXXXXXXX
    export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Safe to re-run: everything is looked up before it is written, and a screenshot already uploaded is
left alone rather than duplicated. Exit code is 1 if the version is not ready to submit once this
has run, with the reasons listed.
"""

from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from asc import BOLD, Client, RESET, app_record, die, good, problem, say, warn
from strings import store

ROOT = Path(__file__).resolve().parent.parent
METADATA = ROOT / "metadata"
FRAMED = ROOT / "build" / "shots" / "framed"
PROJECT = ROOT / "project.yml"

# The store's locale codes, which is what `metadata/` is keyed by. Both localization resources are
# built from this one list: App Store Connect refuses a submission whose app info and version
# disagree about which languages exist, and two lists is how they come to disagree.
LOCALES = sorted(store.NAME)

# Which slot the framed screenshots go in. 6.9-inch is the only iPhone size App Store Connect still
# requires, and every smaller iPhone is served by scaling it down.
DISPLAY_TYPE = "APP_IPHONE_67"

# The one platform this app ships on, spelled the way `reviewSubmissions` wants it.
PLATFORM = "IOS"

# metadata/ file to App Store Connect attribute. Two resources, because Apple splits the listing
# between what belongs to the app (its name) and what belongs to a version (its description).
APP_INFO_FIELDS = {"name": "name", "subtitle": "subtitle", "privacy_url": "privacyPolicyUrl"}
VERSION_FIELDS = {
    "description": "description",
    "keywords": "keywords",
    "promotional_text": "promotionalText",
    "release_notes": "whatsNew",
    "support_url": "supportUrl",
    "marketing_url": "marketingUrl",
}

# metadata/review_information/ file to attribute.
REVIEW_FIELDS = {
    "first_name": "contactFirstName",
    "last_name": "contactLastName",
    "phone_number": "contactPhone",
    "email_address": "contactEmail",
    "notes": "notes",
}

# Versions Apple will still take edits to. A version being reviewed or on sale is not one of them,
# and PATCHing it either fails or, worse, edits the listing customers are reading.
EDITABLE = {
    "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
    "INVALID_BINARY", "WAITING_FOR_EXPORT_COMPLIANCE", "READY_FOR_DISTRIBUTION",
}

# The age rating questionnaire, for an alarm clock whose hardest content is a push-up counter.
#
# Answered here rather than left to a human because every answer is a fact about the app that the
# repository already settles: there is no violence, no gambling, no web view, no user content, and
# no advertising. The declaration hangs off the *app info*, not the version, and it is one app-wide
# resource: answering it once answers it for every version. Sent as one PATCH, and reported rather
# than fatal, because Apple adds questions to this form and a version that is only missing an age
# rating is still a version worth having.
#
# Every one of these is required together: a PATCH naming a subset is refused with one "You must
# provide a value for the attribute" per absentee, so the whole questionnaire goes in every request.
# The split between "NONE" and False is Apple's, not a choice: the twelve graded content categories
# take a level, the capability questions take a yes or no, and sending the wrong JSON type is a 409
# naming the type it wanted. Both spellings mean the same thing here, which is no.
AGE_RATING = {
    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
    "contests": "NONE",
    "gamblingSimulated": "NONE",
    "gunsOrOtherWeapons": "NONE",
    "horrorOrFearThemes": "NONE",
    "matureOrSuggestiveThemes": "NONE",
    "medicalOrTreatmentInformation": "NONE",
    "profanityOrCrudeHumor": "NONE",
    "sexualContentGraphicAndNudity": "NONE",
    "sexualContentOrNudity": "NONE",
    "violenceCartoonOrFantasy": "NONE",
    "violenceRealistic": "NONE",
    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
    "advertising": False,
    # Whether the app checks how old its user is. It does not, and it does not need to: nothing it
    # shows is age-gated. Answering yes is a claim Apple can ask to see implemented.
    "ageAssurance": False,
    "gambling": False,
    # Wellness *topics*, not wellness activity: the app counts push-ups to prove you are awake and
    # gives no advice, no diet, no body-image content and no health readings.
    "healthOrWellnessTopics": False,
    "lootBox": False,
    "messagingAndChat": False,
    "parentalControls": False,
    "socialMedia": False,
    "unrestrictedWebAccess": False,
    # Alarm labels are user-written, but they never leave the device, so there is nothing another
    # user could be shown. The question is about content shared between people.
    "userGeneratedContent": False,
    # Not a kids' category app: the mission screens assume a reader, and the category is
    # Productivity. Declaring an age band would put it in a programme with stricter rules than the
    # app needs.
    "kidsAgeBand": None,
    "ageRatingOverride": "NONE",
}

# Nothing in the bundle is licensed from anyone: see `content_rights`.
CONTENT_RIGHTS = "DOES_NOT_USE_THIRD_PARTY_CONTENT"

# What a placeholder looks like. The listing may not be sent with one: Apple calls this number when
# a review stalls, and an invented contact turns a two-day question into a rejection.
PLACEHOLDERS = ("example.com", "+15555555555", "TODO", "TBD")


# ---------------------------------------------------------------------------
# What to send, read from the repository
# ---------------------------------------------------------------------------


def text(path: Path) -> str:
    if not path.is_file():
        die(f"{path.relative_to(ROOT)} is missing, run scripts/make_metadata.py")
    return path.read_text(encoding="utf-8").strip()


def version_string() -> str:
    """`MARKETING_VERSION` out of project.yml, which is what the build carries.

    Read from there rather than typed here so the version on the store page and the version in the
    binary cannot drift: Apple rejects a submission whose build has a different marketing version
    from the version record it is attached to.
    """
    found = re.search(r'MARKETING_VERSION:\s*"?([0-9][0-9.]*)"?', PROJECT.read_text(encoding="utf-8"))
    if not found:
        die("no MARKETING_VERSION in project.yml")
    return found.group(1)


def listings() -> dict[str, dict[str, str]]:
    """Every locale's files, read once, so a missing one stops the run before the first call."""
    everything = {}
    for locale in LOCALES:
        folder = METADATA / locale
        if not folder.is_dir():
            die(f"metadata/{locale}/ is missing, run scripts/make_metadata.py")
        wanted = set(APP_INFO_FIELDS) | set(VERSION_FIELDS)
        everything[locale] = {name: text(folder / f"{name}.txt") for name in sorted(wanted)}
    return everything


def contact() -> dict[str, str]:
    folder = METADATA / "review_information"
    details = {name: text(folder / f"{name}.txt") for name in REVIEW_FIELDS}
    guilty = [f"{name} ({value})" for name, value in details.items()
              for marker in PLACEHOLDERS if marker in value]
    if guilty:
        die("the review contact is still a placeholder: " + ", ".join(guilty) + "\n\n"
            "  Apple calls it when a review stalls, so it has to reach someone. Put a real email\n"
            "  and phone number in `CONTACT` in scripts/make_metadata.py, re-run that script, and\n"
            "  re-run this one.")
    details["demoAccountRequired"] = text(folder / "demo_account_required.txt") == "true"
    return details


def check_screenshots() -> dict[str, list[Path]]:
    """The framed sets, counted before anything is uploaded.

    Apple takes between three and ten per size, and refuses a set where one language has fewer than
    another only at submission time, which is after all of them are uploaded.
    """
    if not FRAMED.is_dir():
        die("build/shots/framed is missing, run scripts/shots.sh")
    sets, counts = {}, set()
    for locale in LOCALES:
        files = sorted((FRAMED / locale).glob("*.png"))
        if not 3 <= len(files) <= 10:
            die(f"{locale} has {len(files)} screenshots; Apple takes three to ten")
        sets[locale] = files
        counts.add(len(files))
    if len(counts) > 1:
        die(f"the languages disagree on how many screenshots there are: {sorted(counts)}")
    return sets


# ---------------------------------------------------------------------------
# Small shared pieces
# ---------------------------------------------------------------------------


def write(client: Client, resource: str, existing: str | None, attributes: dict,
          relationships: dict | None = None, at_creation: dict | None = None) -> str:
    """PATCH what exists, POST what does not.

    `at_creation` carries the attributes Apple only takes on the way in, `locale` above all: it is
    part of a localization's identity, and sending it in a PATCH is an error rather than a no-op.
    """
    if existing:
        client.expect("PATCH", f"/v1/{resource}/{existing}",
                      {"data": {"type": resource, "id": existing, "attributes": attributes}})
        return existing
    body: dict = {"data": {"type": resource, "attributes": {**attributes, **(at_creation or {})}}}
    if relationships:
        body["data"]["relationships"] = relationships
    return client.expect("POST", f"/v1/{resource}", body)["data"]["id"]


def by_locale(client: Client, path: str) -> dict[str, str]:
    return {entry["attributes"]["locale"]: entry["id"] for entry in client.collection(path)}


# ---------------------------------------------------------------------------
# The app: name, subtitle, categories
# ---------------------------------------------------------------------------


def app_info(client: Client, app_id: str) -> str:
    """The editable app info record, of which there is one, or two during a review.

    An app being reviewed has a frozen copy and a live copy; the name in the frozen one cannot be
    edited, and picking the wrong one means every localization below is refused.
    """
    infos = client.collection(f"/v1/apps/{app_id}/appInfos?limit=200")
    editable = [entry for entry in infos
                if (entry["attributes"].get("appStoreState")
                    or entry["attributes"].get("state", "")) in EDITABLE]
    if not editable:
        states = ", ".join(sorted(entry["attributes"].get("appStoreState")
                                  or entry["attributes"].get("state", "?") for entry in infos))
        die(f"no editable app info: the app is {states}. Wait for the review to end, or create the "
            "next version in App Store Connect.")
    good("app info", editable[0]["id"])
    return editable[0]["id"]


def categories(client: Client, info_id: str) -> None:
    primary = text(METADATA / "primary_category.txt")
    secondary = text(METADATA / "secondary_category.txt")
    client.expect("PATCH", f"/v1/appInfos/{info_id}", {"data": {
        "type": "appInfos",
        "id": info_id,
        "relationships": {
            "primaryCategory": {"data": {"type": "appCategories", "id": primary}},
            "secondaryCategory": {"data": {"type": "appCategories", "id": secondary}}}}})
    good("categories", f"{primary}, {secondary}")


def app_info_localizations(client: Client, info_id: str, everything: dict) -> None:
    existing = by_locale(client, f"/v1/appInfos/{info_id}/appInfoLocalizations?limit=200")
    written = 0
    for locale in LOCALES:
        attributes = {field: everything[locale][name] for name, field in APP_INFO_FIELDS.items()}
        write(client, "appInfoLocalizations", existing.get(locale), attributes,
              relationships={"appInfo": {"data": {"type": "appInfos", "id": info_id}}},
              at_creation={"locale": locale})
        written += 1
    good("app info localizations", f"{written} of {len(LOCALES)}, name and subtitle")


# ---------------------------------------------------------------------------
# The version: description, screenshots, review details
# ---------------------------------------------------------------------------


def version(client: Client, app_id: str, number: str) -> str:
    """The version record this listing goes on, renumbered rather than duplicated if need be.

    A new app record arrives with a version already on it, called "1.0" whatever the build says, and
    Apple refuses a second one while that one is open: `POST /v1/appStoreVersions` answers 409 "You
    cannot create a new version of the App in the current state." Since a build only attaches to a
    version carrying its own marketing version, and 1.0 is not 1.0.0, the open one is renumbered.

    Any version Apple still takes edits to will do, whatever it is called. One that is closed and
    already carries this number is fatal, because the next release is a decision in project.yml.
    """
    open_versions = []
    for entry in client.collection(f"/v1/apps/{app_id}/appStoreVersions?limit=200"):
        attributes = entry["attributes"]
        state = attributes.get("appStoreState") or attributes.get("appVersionState", "")
        if state in EDITABLE:
            open_versions.append((entry["id"], attributes["versionString"], state))
        elif attributes["versionString"] == number:
            die(f"version {number} is {state}, which takes no edits. Bump MARKETING_VERSION in "
                "project.yml for the next one.")

    if open_versions:
        identifier, existing, state = open_versions[0]
        attributes = {"copyright": text(METADATA / "copyright.txt")}
        if existing != number:
            attributes["versionString"] = number
        client.expect("PATCH", f"/v1/appStoreVersions/{identifier}", {"data": {
            "type": "appStoreVersions", "id": identifier, "attributes": attributes}})
        good(f"version {number}", f"{identifier}, {state}"
                                  + (f", renumbered from {existing}" if existing != number else ""))
        return identifier

    created = client.expect("POST", "/v1/appStoreVersions", {"data": {
        "type": "appStoreVersions",
        "attributes": {
            "platform": "IOS",
            "versionString": number,
            "copyright": text(METADATA / "copyright.txt"),
            # Nothing goes on sale because a script ran. Apple's other options release the app the
            # moment review passes, which is a decision that belongs to whoever is watching.
            "releaseType": "MANUAL",
        },
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})
    good(f"version {number} created", created["data"]["id"])
    return created["data"]["id"]


def first_release(client: Client, app_id: str, version_id: str) -> bool:
    """Whether this version is the only one the app has ever had, which decides one field below."""
    return [entry["id"] for entry in client.collection(
        f"/v1/apps/{app_id}/appStoreVersions?limit=200")] == [version_id]


def version_localizations(client: Client, version_id: str, everything: dict,
                          first_release: bool) -> dict[str, str]:
    """The description, keywords and the rest, in twelve languages.

    Everything but the release notes, on a first version. Apple answers `whatsNew` on one with 409
    "Attribute 'whatsNew' cannot be edited at this time", and it is right: there is nothing new about
    an app nobody has seen, and its own page does not draw the box. The refusal is not partial
    either, so sending it would lose the description along with it.
    """
    fields = {name: field for name, field in VERSION_FIELDS.items()
              if not (first_release and field == "whatsNew")}
    existing = by_locale(client,
                         f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=200")
    identifiers = {}
    for locale in LOCALES:
        attributes = {field: everything[locale][name] for name, field in fields.items()}
        identifiers[locale] = write(
            client, "appStoreVersionLocalizations", existing.get(locale), attributes,
            relationships={"appStoreVersion": {
                "data": {"type": "appStoreVersions", "id": version_id}}},
            at_creation={"locale": locale})
    good("version localizations", f"{len(identifiers)} of {len(LOCALES)}, {len(fields)} fields each"
                                 + (", release notes held back for a first version" if first_release
                                    else ""))
    return identifiers


def review_details(client: Client, version_id: str, details: dict) -> None:
    status, payload = client.call("GET", f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
    # `or {}` and not a default: a to-one relationship that holds nothing answers 200 with `data`
    # present and null, so the default never applies and the key is there to be tripped over.
    existing = (payload.get("data") or {}).get("id") if status < 300 else None
    attributes = {field: details[name] for name, field in REVIEW_FIELDS.items()}
    attributes["demoAccountRequired"] = details["demoAccountRequired"]
    write(client, "appStoreReviewDetails", existing, attributes,
          relationships={"appStoreVersion": {
              "data": {"type": "appStoreVersions", "id": version_id}}})
    good("review details", f"{details['email_address']}, {len(details['notes'])} characters of notes")


# ---------------------------------------------------------------------------
# The screenshots
# ---------------------------------------------------------------------------


def screenshot_set(client: Client, localization_id: str) -> str:
    for entry in client.collection(
            f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=200"):
        if entry["attributes"]["screenshotDisplayType"] == DISPLAY_TYPE:
            return entry["id"]
    return client.expect("POST", "/v1/appScreenshotSets", {"data": {
        "type": "appScreenshotSets",
        "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
        "relationships": {"appStoreVersionLocalization": {
            "data": {"type": "appStoreVersionLocalizations", "id": localization_id}}}}})["data"]["id"]


def upload_screenshots(client: Client, set_id: str, files: list[Path]) -> tuple[int, int]:
    """Reserve, upload, commit, once per file, in filename order.

    The order matters twice: the store shows them in the order of the set, and that order is the
    order they were created in, which is why this walks a sorted list rather than a directory.

    A file already on record is left alone. Apple has no upsert here, so re-running would otherwise
    give a language twelve screenshots, and Apple only takes ten.
    """
    existing = {entry["attributes"]["fileName"] for entry in client.collection(
        f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=200")}
    written = 0
    for path in files:
        if path.name in existing:
            continue
        blob = path.read_bytes()
        created = client.expect("POST", "/v1/appScreenshots", {"data": {
            "type": "appScreenshots",
            "attributes": {"fileSize": len(blob), "fileName": path.name},
            "relationships": {"appScreenshotSet": {
                "data": {"type": "appScreenshotSets", "id": set_id}}}}})
        client.upload(created["data"]["attributes"]["uploadOperations"], blob)
        client.expect("PATCH", f"/v1/appScreenshots/{created['data']['id']}", {"data": {
            "type": "appScreenshots",
            "id": created["data"]["id"],
            # Apple verifies this against the bytes that arrived and marks the asset failed, not the
            # request, so a truncated upload is only ever visible here or on the store page.
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
        written += 1
    return len(existing) + written, written


# ---------------------------------------------------------------------------
# The parts that are answers rather than copy
# ---------------------------------------------------------------------------


def age_rating(client: Client, info_id: str) -> str:
    """Answer the questionnaire on the app info.

    On the *app info*, deliberately: `/v1/appStoreVersions/{id}/ageRatingDeclaration` is a 404 that
    says the relationship does not exist, and the 404 is Apple's, not a typo here. The declaration's
    own id is the app info's id, which makes the GET look redundant and is why it stays: an id that
    happens to be equal today is not an id to hard-code.
    """
    status, payload = client.call("GET", f"/v1/appInfos/{info_id}/ageRatingDeclaration")
    declaration = (payload.get("data") or {}).get("id") if status < 300 else None
    if not declaration:
        return "no declaration to answer"
    status, payload = client.call("PATCH", f"/v1/ageRatingDeclarations/{declaration}", {"data": {
        "type": "ageRatingDeclarations", "id": declaration, "attributes": AGE_RATING}})
    if status >= 300:
        warn(f"the age rating was refused: {problem(payload)}\n"
             "  Answer it by hand in App Store Connect: App Information, Age Rating, Edit.")
        return "needs a human"
    # What Apple did *not* ask, so that a question added next year shows up here rather than as a
    # rejected submission. Unanswered is not the same as answered no.
    answered = payload["data"]["attributes"]
    unanswered = sorted(name for name, value in answered.items() if value is None) or ["nothing"]
    return (f"{len(AGE_RATING)} answers, no objectionable content, "
            f"unanswered: {', '.join(unanswered)}")


def staged(client: Client, app_id: str) -> str | None:
    """The draft submission that has frozen the listing, if there is one.

    A version that is an item of a submission stops taking metadata edits, and so does the app info
    beside it: `appInfos` goes to READY_FOR_REVIEW and every localization PATCH below is refused. That
    is not a failure, it is the state this script exists to reach, so it is worth recognising before
    anything is attempted rather than reporting it as "no editable app info" twenty calls later.
    """
    for draft in client.collection(f"/v1/apps/{app_id}/reviewSubmissions?limit=50"):
        if draft["attributes"]["submittedDate"]:
            continue
        if client.collection(f"/v1/reviewSubmissions/{draft['id']}/items?limit=50"):
            return draft["id"]
    return None


def submission(client: Client, app_id: str, version_id: str) -> str:
    """Stage the review submission, and stop one click short of sending it.

    Worth doing even though nobody here will press the button, because adding the version to a
    submission is the only complete pre-flight Apple offers. Every other check in this file knows one
    field; this call knows the whole list, and it answers with it: a 409 whose associated errors name
    the app privacy answers, the pricing, the content rights, each against the path it belongs to.
    Nothing else in the API will tell you the version is short of something.

    What it deliberately does not do is `PATCH {"submitted": true}`. That hands the app to Apple's
    reviewers under someone else's developer account and their legal declarations, which is a person's
    act. A staged submission is also reversible from the browser, and a sent one is not.
    """
    for draft in client.collection(f"/v1/apps/{app_id}/reviewSubmissions?limit=50"):
        if draft["attributes"]["submittedDate"]:
            continue
        identifier = draft["id"]
        break
    else:
        status, payload = client.call("POST", "/v1/reviewSubmissions", {"data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": PLATFORM},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})
        if status >= 300:
            warn(f"the submission could not be staged: {problem(payload)}")
            return "needs a human"
        identifier = payload["data"]["id"]

    items = client.collection(f"/v1/reviewSubmissions/{identifier}/items"
                              "?include=appStoreVersion&limit=50")
    held = {(item.get("relationships", {}).get("appStoreVersion", {}).get("data") or {}).get("id")
            for item in items}
    if version_id in held:
        return f"{len(items)} item staged, ready to send"

    status, payload = client.call("POST", "/v1/reviewSubmissionItems", {"data": {
        "type": "reviewSubmissionItems",
        "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": identifier}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})
    if status >= 300:
        warn("Apple will not review this version yet:\n  " + problem(payload).replace("; ", "\n  "))
        return "not reviewable yet"
    # The three products are not items of their own: `reviewSubmissionItems` has no relationship for
    # a subscription or a purchase, and on a first version Apple reviews everything that is ready to
    # submit alongside the app. `scripts/iap.py` is what makes them ready.
    return "version staged, ready to send"


def content_rights(client: Client, app_id: str) -> str:
    """Whether the app ships anything somebody else owns.

    It does not, and that is a fact about this repository rather than an opinion: the eight alarm
    tones are synthesised by `scripts/make-sounds.swift`, the icon by `scripts/make-icon.swift`,
    there is no bundled font, and `DawnbreakKit` declares no package dependencies. Left unanswered
    this alone blocks the submission, and it is not a question a person needs to weigh.
    """
    status, payload = client.call("GET", f"/v1/apps/{app_id}?fields[apps]=contentRightsDeclaration")
    declared = payload["data"]["attributes"]["contentRightsDeclaration"] if status < 300 else None
    if declared == CONTENT_RIGHTS:
        return "no third party content"
    status, payload = client.call("PATCH", f"/v1/apps/{app_id}", {"data": {
        "type": "apps", "id": app_id,
        "attributes": {"contentRightsDeclaration": CONTENT_RIGHTS}}})
    if status >= 300:
        warn(f"the content rights declaration was refused: {problem(payload)}")
        return "needs a human"
    return "no third party content, newly declared"


def priced_in(client: Client, app_id: str) -> int:
    """How many territories the app itself has a price in.

    Counted, not inferred from the schedule existing, because an empty schedule exists: see `free`.
    Both collections answer 404 while the schedule holds nothing, which is not an error to report
    but the answer zero.
    """
    territories = 0
    for relationship in ("manualPrices", "automaticPrices"):
        status, payload = client.call(
            "GET", f"/v1/appPriceSchedules/{app_id}/{relationship}?limit=200")
        if status < 300:
            territories += payload.get("meta", {}).get("paging", {}).get("total", 0)
    return territories


def free(client: Client, app_id: str) -> str:
    """Price zero, once, if nothing has priced the app yet.

    An app with no price schedule cannot be submitted, and this app is free: the three products are
    what it sells. Only ever set when absent, because changing what an app costs is a decision.

    The `territory` on the included price is what makes the schedule hold anything. Without it Apple
    answers 201 and builds a schedule with no prices in it, then refuses the submission from
    somewhere else entirely: "App is not eligible for submission until pricing has been set", about a
    schedule that reads as present. Same trap as the purchase schedules in `scripts/iap.py`.
    """
    already = priced_in(client, app_id)
    if already:
        return f"already free in {already} territories"
    points = client.collection(f"/v1/apps/{app_id}/appPricePoints?filter[territory]=USA&limit=200")
    zero = next((point for point in points
                 if point["attributes"]["customerPrice"] in ("0", "0.0", "0.00")), None)
    if not zero:
        return "no free price point offered; set the price by hand"
    status, payload = client.call("POST", "/v1/appPriceSchedules", {
        "data": {
            "type": "appPriceSchedules",
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}},
                "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                "manualPrices": {"data": [{"type": "appPrices", "id": "${price}"}]}}},
        "included": [{
            "type": "appPrices",
            "id": "${price}",
            "attributes": {"startDate": None},
            "relationships": {
                "appPricePoint": {"data": {"type": "appPricePoints", "id": zero["id"]}},
                "territory": {"data": {"type": "territories", "id": "USA"}}}}]})
    if status >= 300:
        warn(f"the price schedule was refused: {problem(payload)}")
        return "needs a human"
    return f"free in {priced_in(client, app_id)} territories"


def attach_build(client: Client, app_id: str, version_id: str, number: str) -> str:
    """The build the version ships, if one has finished processing.

    A version with no build cannot be submitted, and the build comes from `scripts/release.sh`, so
    this reports rather than insists: the newest processed build is attached, and if there is none
    the reason is the sentence a reader needs.
    """
    status, payload = client.call("GET", f"/v1/appStoreVersions/{version_id}/build")
    if status < 300 and payload.get("data"):
        return "already attached"
    builds = client.collection(
        f"/v1/builds?filter[app]={app_id}&filter[preReleaseVersion.version]={number}"
        "&sort=-uploadedDate&limit=200")
    ready = [entry for entry in builds if entry["attributes"].get("processingState") == "VALID"]
    if not ready:
        waiting = [entry["attributes"].get("processingState") for entry in builds]
        return (f"no processed build for {number} yet" if not waiting
                else f"the {number} builds are {', '.join(waiting)}")
    newest = ready[0]
    status, payload = client.call(
        "PATCH", f"/v1/appStoreVersions/{version_id}/relationships/build",
        {"data": {"type": "builds", "id": newest["id"]}})
    if status >= 300:
        warn(f"the build could not be attached: {problem(payload)}")
        return "needs a human"
    return f"build {newest['attributes'].get('version')} attached"


# ---------------------------------------------------------------------------


def main() -> int:
    number = version_string()
    say(f"The {number} listing, from metadata/ and build/shots/framed/")
    everything = listings()
    details = contact()
    shots = check_screenshots()
    good("read from the repository", f"{len(LOCALES)} locales, "
                                    f"{sum(len(files) for files in shots.values())} screenshots")

    client = Client()
    app = app_record(client)
    good("app record", f"{app['attributes']['name']} ({app['id']})")

    if staged(client, app["id"]):
        print()
        say(f"Version {number} is staged for review, and the listing is frozen while it is")
        print("  Nothing to send: App Store Connect refuses metadata edits while a submission holds")
        print("  the version. To change the listing, take it out of the draft first:\n")
        print("    Distribution → Vérification de l'app → the draft → remove the item\n")
        print("  and re-run this. To send it instead: the same draft, Envoyer pour vérification.")
        return 0

    print(f"\n{BOLD}App information{RESET}")
    info_id = app_info(client, app["id"])
    categories(client, info_id)
    app_info_localizations(client, info_id, everything)
    good("age rating", age_rating(client, info_id))

    print(f"\n{BOLD}Version {number}{RESET}")
    version_id = version(client, app["id"], number)
    localizations = version_localizations(client, version_id, everything,
                                         first_release(client, app["id"], version_id))
    review_details(client, version_id, details)
    good("content rights", content_rights(client, app["id"]))
    good("price", free(client, app["id"]))
    good("build", attach_build(client, app["id"], version_id, number))

    print(f"\n{BOLD}Screenshots{RESET}")
    for locale in LOCALES:
        set_id = screenshot_set(client, localizations[locale])
        held, written = upload_screenshots(client, set_id, shots[locale])
        good(locale, f"{held} in the {DISPLAY_TYPE} set"
                     + (f", {written} uploaded" if written else ", nothing new"))

    print(f"\n{BOLD}Submission{RESET}")
    good("review submission", submission(client, app["id"], version_id))

    print()
    state = client.expect("GET", f"/v1/appStoreVersions/{version_id}")["data"]["attributes"]
    say(f"Version {number} is {state.get('appStoreState') or state.get('appVersionState', '?')}")
    print("  What is left is a person, not a script:\n")
    print("    App Store Connect → Dawnbreak → Distribution → read the page as a reviewer will")
    print("    → Vérification de l'app / App Review → the draft → Envoyer pour vérification\n")
    print("  App privacy is the one required answer no API can give: it is web-only, under")
    print("  Distribution → Confidentialité de l'app, and it has to be published, not just saved.")
    print("  Everything else the version needs, this script sends, and the submission step above")
    print("  refuses to stage anything Apple would not review.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
