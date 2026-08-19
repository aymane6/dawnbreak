#!/usr/bin/env python3
"""The three things the app sells, in App Store Connect, from the local StoreKit file.

    python3 scripts/iap.py

Creates, or reuses, and then reports:

    one subscription group    Dawnbreak Pro, named in twelve languages
    two subscriptions         com.aymbam.dawnbreak.pro.monthly (P1M) and .yearly (P1Y)
    one non-consumable        com.aymbam.dawnbreak.pro.lifetime
    twelve localizations      on each product, display name and description
    one price                 on each, in the base territory, equalized by Apple from there
    a free week               the yearly plan's introductory offer
    a review screenshot       on each, if build/shots/review/paywall.png has been captured

Ids, prices, periods and family sharing are read from Configuration/Dawnbreak.storekit rather than
repeated here. That file is what the simulator sells and what `scripts/asc-preflight.py` checks the
Swift against, so it stays the one place a product id can be wrong in. Display names and
descriptions come from `scripts/strings/store.py`, where the rest of the store copy lives.

It needs the app record to exist and cannot make one: `POST /v1/apps` is refused for an API key.
Everything else here is allowed, which is why this is a script and not a page of instructions.

Safe to re-run. Every step looks for what it would create and only writes what is missing. A price
is only ever set on a product this run has just created: changing the price of a subscription
somebody is already paying for is a decision, not a repair.

    export ASC_KEY_ID=XXXXXXXXXX
    export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Exit code is 1 if App Store Connect still calls a product incomplete once this has run. Each
product's state is asked for at the end rather than assumed, because Apple is the only one that
knows which field it is still waiting for.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from asc import BOLD, Client, RESET, app_record, bad, die, good, problem, say, warn
from strings import store

ROOT = Path(__file__).resolve().parent.parent
STOREKIT = ROOT / "Configuration" / "Dawnbreak.storekit"

# Apple wants a picture of the purchase screen alongside each product, and it is not one of the
# store screenshots: those are framed, captioned marketing images, this is evidence of what the
# paywall says. `scripts/shots.sh --review` writes it.
REVIEW_SHOT = ROOT / "build" / "shots" / "review" / "paywall.png"

# In-app purchases live under /v2, and their subresources with them. Subscriptions are /v1.
PURCHASES = "/v2/inAppPurchases"

# The territory a price is set in; Apple equalizes the rest from it. One price per product is
# therefore enough, and the number of territories that came back priced is worth printing: if
# equalization did not happen the product cannot be sold, and only App Store Connect knows.
BASE_TERRITORY = "USA"

# StoreKit writes ISO 8601 durations, the API wants names. Only the ones a subscription may use.
PERIODS = {
    "P1W": "ONE_WEEK", "P1M": "ONE_MONTH", "P2M": "TWO_MONTHS",
    "P3M": "THREE_MONTHS", "P6M": "SIX_MONTHS", "P1Y": "ONE_YEAR",
}

# What StoreKit calls a payment mode and what the API calls one.
OFFER_MODES = {"free": "FREE_TRIAL", "payAsYouGo": "PAY_AS_YOU_GO", "payUpFront": "PAY_UP_FRONT"}

# Subscriptions and purchases were each given their own review screenshot resource rather than one
# shared one, so the collection, the relationship name and the type it points at all differ.
# Everything else about the three step upload is the same. (resource, relationship, target type)
SUBSCRIPTION_SHOT = ("subscriptionAppStoreReviewScreenshots", "subscription", "subscriptions")
PURCHASE_SHOT = ("inAppPurchaseAppStoreReviewScreenshots", "inAppPurchaseV2", "inAppPurchases")

# Attached to every product, read by a reviewer who has the build and has to find the paywall.
# English only, and short: this is a note to one person, not copy.
REVIEW_NOTE = (
    "Pro is one entitlement sold three ways; any of the three unlocks the same features. "
    "To reach the purchase screen: Settings, then Dawnbreak Pro. It also appears when a second "
    "alarm is added, since the free tier allows one. Restore Purchases is on the same screen. "
    "There is no account and no server: the entitlement comes from Transaction.currentEntitlements."
)

# The store's locale codes, which are not the app's language codes: the App Store wants en-US where
# the bundle has en. Every table here is keyed by the store's, and checked against this list.
LOCALES = sorted(store.NAME)


# ---------------------------------------------------------------------------
# What to create, read from the StoreKit configuration
# ---------------------------------------------------------------------------


def configuration() -> dict:
    """The StoreKit file, and the one subscription group in it.

    A second group would mean two separate things being sold, which neither this script nor the app
    expects, so it is refused here rather than half handled.
    """
    if not STOREKIT.is_file():
        die(f"{STOREKIT.relative_to(ROOT)} is missing, and it is where the products are defined")
    document = json.loads(STOREKIT.read_text(encoding="utf-8"))
    groups = document.get("subscriptionGroups", [])
    if len(groups) != 1:
        die(f"{STOREKIT.name} has {len(groups)} subscription groups; this script expects one")
    return document


def plan(product_id: str) -> str:
    """`com.aymbam.dawnbreak.pro.monthly` to `monthly`, which is how the copy tables are keyed."""
    key = product_id.rsplit(".", 1)[-1]
    if key not in store.IAP_NAME:
        die(f"{product_id} has no display name in store.IAP_NAME (looked for {key!r})")
    return key


def check_copy() -> None:
    """Every table, before the first call.

    A display name over thirty characters is refused on the product it belongs to, halfway through a
    run, leaving the rest to be repeated against half made products. Counting here costs nothing and
    moves the failure to before anything exists.
    """
    problems = []
    for name, table, limit in store.PRODUCT_FIELDS:
        for locale in LOCALES:
            if locale not in table:
                problems.append(f"{name} has no {locale}")
            elif len(table[locale]) > limit:
                problems.append(f"{name}/{locale}: {len(table[locale])} characters, limit {limit}")
        for locale in table:
            if locale not in LOCALES:
                problems.append(f"{name} has {locale}, which the listing does not")
    if len(store.IAP_GROUP_NAME) > 30:
        problems.append(f"IAP_GROUP_NAME: {len(store.IAP_GROUP_NAME)} characters, limit 30")
    if problems:
        die("the product copy is not sendable:\n  " + "\n  ".join(problems))
    good("product copy", f"{len(store.PRODUCT_FIELDS)} fields, {len(LOCALES)} locales, within limits")


# ---------------------------------------------------------------------------
# Small shared pieces
# ---------------------------------------------------------------------------


def total(client: Client, path: str) -> int:
    """How many rows a collection holds, from Apple's own count rather than by fetching them.

    For the two report lines that are about a number and not about the contents: how many
    territories a product ended up priced or available in, which is several hundred rows to download
    for one integer. Negative when the collection could not be read, so the caller can say so
    instead of printing a zero it did not measure.
    """
    status, payload = client.call("GET", path)
    if status >= 300:
        return -1
    counted = payload.get("meta", {}).get("paging", {}).get("total")
    return counted if isinstance(counted, int) else len(payload.get("data", []))


def state(client: Client, path: str) -> str:
    """What App Store Connect thinks of a product now: READY_TO_SUBMIT, MISSING_METADATA, ...

    Asked for rather than inferred. This script knows what it sent; only Apple knows what it wants,
    and the answer is the difference between a product that goes with the build and one that
    silently holds the whole submission back.
    """
    status, payload = client.call("GET", path)
    if status >= 300:
        return "UNKNOWN"
    return payload.get("data", {}).get("attributes", {}).get("state", "UNKNOWN")


def price_point(client: Client, path: str, price: str) -> str:
    """The price point whose customer price is exactly what the StoreKit file says.

    There are several hundred per product per territory, so this matches on the price rather than
    computing a tier. If that exact price is not offered, the nearest three are printed and the run
    stops: an invented price would be a silent difference between what the simulator sells and what
    the store charges.
    """
    points = client.collection(f"{path}?filter[territory]={BASE_TERRITORY}&limit=200")
    if not points:
        die(f"{BASE_TERRITORY} returned no price points from {path}")
    match = next((point for point in points if point["attributes"]["customerPrice"] == price), None)
    if match:
        return match["id"]
    nearest = sorted(points, key=lambda point: abs(
        float(point["attributes"]["customerPrice"]) - float(price)))[:3]
    die(f"{BASE_TERRITORY} has no price point at {price}; nearest are "
        + ", ".join(point["attributes"]["customerPrice"] for point in nearest))
    raise AssertionError  # unreachable, for the type checker


def review_screenshot(client: Client, owner: str, product_id: str, kind: tuple[str, str, str]) -> str:
    """Reserve, upload, commit. Identical for a subscription and for a purchase bar the names.

    Returns what to print about it. A missing file is not fatal here; it is fatal in `main`, through
    the state Apple reports for the product, which is the difference between guessing that Apple
    wants this and being told.
    """
    resource, relationship, target = kind
    if client.call("GET", f"{owner}/appStoreReviewScreenshot")[1].get("data"):
        return "screenshot on record"
    if not REVIEW_SHOT.is_file():
        return "no screenshot"
    blob = REVIEW_SHOT.read_bytes()
    created = client.expect("POST", f"/v1/{resource}", {"data": {
        "type": resource,
        "attributes": {"fileSize": len(blob), "fileName": REVIEW_SHOT.name},
        "relationships": {relationship: {"data": {"type": target, "id": product_id}}}}})
    client.upload(created["data"]["attributes"]["uploadOperations"], blob)
    client.expect("PATCH", f"/v1/{resource}/{created['data']['id']}", {"data": {
        "type": resource,
        "id": created["data"]["id"],
        # Apple compares the checksum against what arrived and then fails the asset rather than the
        # request, so a truncated upload is only ever visible here.
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
    return f"screenshot {len(blob) // 1024} KB"


def report(product_id: str, notes: list[str], verdict: str) -> bool:
    """One line per product, and whether Apple considers it finished."""
    notes.append(verdict)
    if verdict == "MISSING_METADATA":
        bad(f"{product_id}: {', '.join(notes)}")
        return False
    good(product_id, ", ".join(notes))
    return True


# ---------------------------------------------------------------------------
# The subscription group
# ---------------------------------------------------------------------------


def group(client: Client, app_id: str, reference_name: str) -> str:
    groups = client.collection(f"/v1/apps/{app_id}/subscriptionGroups?limit=200")
    for entry in groups:
        if entry["attributes"]["referenceName"] == reference_name:
            good("subscription group", f"{reference_name} ({entry['id']})")
            return entry["id"]
    if groups:
        names = ", ".join(entry["attributes"]["referenceName"] for entry in groups)
        die(f"this app already has a subscription group, under another name: {names}\n\n"
            "  Adding a second one is not undoable from here: a group cannot be deleted once it\n"
            "  holds a subscription, and two groups selling the same thing let one customer buy\n"
            f"  both. Either rename that group to {reference_name!r} in App Store Connect, or\n"
            f"  change the group's `name` in {STOREKIT.name} to match it, then re-run.")
    created = client.expect("POST", "/v1/subscriptionGroups", {"data": {
        "type": "subscriptionGroups",
        "attributes": {"referenceName": reference_name},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})
    good("subscription group created", f"{reference_name} ({created['data']['id']})")
    return created["data"]["id"]


def group_localizations(client: Client, group_id: str) -> None:
    """The group's display name, in twelve languages, all of them the same string.

    Not an oversight: a brand name is not translated. It is sent twelve times anyway because a group
    with a locale missing cannot be submitted, and a missing locale there fails the submission
    rather than falling back to English.
    """
    existing = {entry["attributes"]["locale"] for entry in client.collection(
        f"/v1/subscriptionGroups/{group_id}/subscriptionGroupLocalizations?limit=200")}
    written = 0
    for locale in LOCALES:
        if locale in existing:
            continue
        client.expect("POST", "/v1/subscriptionGroupLocalizations", {"data": {
            "type": "subscriptionGroupLocalizations",
            "attributes": {"name": store.IAP_GROUP_NAME, "locale": locale},
            "relationships": {"subscriptionGroup": {
                "data": {"type": "subscriptionGroups", "id": group_id}}}}})
        written += 1
    detail = f"{len(existing) + written} of {len(LOCALES)}"
    good("group localizations", detail + (f", {written} new" if written else ""))


# ---------------------------------------------------------------------------
# The two subscriptions
# ---------------------------------------------------------------------------


def subscription(client: Client, group_id: str, spec: dict) -> tuple[str, bool]:
    product_id = spec["productID"]
    for entry in client.collection(f"/v1/subscriptionGroups/{group_id}/subscriptions?limit=200"):
        if entry["attributes"]["productId"] == product_id:
            return entry["id"], False
    created = client.expect("POST", "/v1/subscriptions", {"data": {
        "type": "subscriptions",
        "attributes": {
            "name": spec["referenceName"],
            "productId": product_id,
            "subscriptionPeriod": PERIODS[spec["recurringSubscriptionPeriod"]],
            "familySharable": spec.get("familyShareable", False),
            # Both plans at the same level, which is what makes a switch a crossgrade rather than an
            # upgrade: they sell the same features for a different period, so neither is above the
            # other and a change takes effect at the next renewal instead of immediately.
            "groupLevel": spec.get("groupNumber", 1),
            "availableInAllTerritories": True,
            "reviewNote": REVIEW_NOTE,
        },
        # `group`, not `subscriptionGroup`: the relationship is named after the thing, the resource
        # after its type.
        "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": group_id}}}}})
    return created["data"]["id"], True


def subscription_localizations(client: Client, subscription_id: str, key: str) -> int:
    existing = {entry["attributes"]["locale"] for entry in client.collection(
        f"/v1/subscriptions/{subscription_id}/subscriptionLocalizations?limit=200")}
    for locale in LOCALES:
        if locale in existing:
            continue
        client.expect("POST", "/v1/subscriptionLocalizations", {"data": {
            "type": "subscriptionLocalizations",
            "attributes": {
                "name": store.IAP_NAME[key][locale],
                "description": store.IAP_DESCRIPTION[locale],
                "locale": locale,
            },
            "relationships": {"subscription": {
                "data": {"type": "subscriptions", "id": subscription_id}}}}})
        existing.add(locale)
    return len(existing)


def subscription_price(client: Client, subscription_id: str, price: str) -> None:
    point = price_point(client, f"/v1/subscriptions/{subscription_id}/pricePoints", price)
    client.expect("POST", "/v1/subscriptionPrices", {"data": {
        "type": "subscriptionPrices",
        # No start date: the price applies as soon as the plan goes live. Nothing is subscribed yet,
        # so there is no current price worth preserving either.
        "attributes": {"startDate": None, "preserveCurrentPrice": False},
        "relationships": {
            "subscription": {"data": {"type": "subscriptions", "id": subscription_id}},
            "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": point}},
            "territory": {"data": {"type": "territories", "id": BASE_TERRITORY}}}}})


def introductory_offer(client: Client, subscription_id: str, spec: dict) -> str | None:
    """The free week on the yearly plan, mirroring the StoreKit file.

    Reported rather than fatal. Everything else here decides whether the plan can be sold; this
    decides whether the first week is free, and a plan that is live without it is still live. If
    Apple refuses it, the reason is printed and the run carries on.
    """
    offer = spec.get("introductoryOffer")
    if not offer:
        return None
    if client.collection(f"/v1/subscriptions/{subscription_id}/introductoryOffers?limit=200"):
        return "offer on record"
    mode = OFFER_MODES.get(offer.get("paymentMode", "free"), "FREE_TRIAL")
    period = offer["subscriptionPeriod"]
    status, payload = client.call("POST", "/v1/subscriptionIntroductoryOffers", {"data": {
        "type": "subscriptionIntroductoryOffers",
        "attributes": {"duration": PERIODS[period], "offerMode": mode, "numberOfPeriods": 1},
        # No territory relationship: an offer without one is offered wherever the plan is sold.
        "relationships": {"subscription": {
            "data": {"type": "subscriptions", "id": subscription_id}}}}})
    if status >= 300:
        warn(f"the {period} introductory offer was refused: {problem(payload)}")
        return None
    return f"{PERIODS[period].lower().replace('_', ' ')} {mode.lower().replace('_', ' ')}"


# ---------------------------------------------------------------------------
# The lifetime purchase
# ---------------------------------------------------------------------------


def purchase(client: Client, app_id: str, spec: dict) -> tuple[str, bool]:
    product_id = spec["productID"]
    for entry in client.collection(f"/v1/apps/{app_id}/inAppPurchasesV2?limit=200"):
        if entry["attributes"]["productId"] == product_id:
            return entry["id"], False
    created = client.expect("POST", PURCHASES, {"data": {
        "type": "inAppPurchases",
        "attributes": {
            "name": spec["referenceName"],
            "productId": product_id,
            "inAppPurchaseType": "NON_CONSUMABLE",
            "familySharable": spec.get("familyShareable", False),
            "reviewNote": REVIEW_NOTE,
        },
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})
    return created["data"]["id"], True


def purchase_localizations(client: Client, purchase_id: str, key: str) -> int:
    existing = {entry["attributes"]["locale"] for entry in client.collection(
        f"{PURCHASES}/{purchase_id}/inAppPurchaseLocalizations?limit=200")}
    for locale in LOCALES:
        if locale in existing:
            continue
        client.expect("POST", "/v1/inAppPurchaseLocalizations", {"data": {
            "type": "inAppPurchaseLocalizations",
            "attributes": {
                "name": store.IAP_NAME[key][locale],
                "description": store.IAP_DESCRIPTION_LIFETIME[locale],
                "locale": locale,
            },
            # `inAppPurchaseV2` holding a resource of type `inAppPurchases`: Apple's naming, not a
            # typo. The v1 relationship of the same name points at the retired resource.
            "relationships": {"inAppPurchaseV2": {
                "data": {"type": "inAppPurchases", "id": purchase_id}}}}})
        existing.add(locale)
    return len(existing)


def purchase_price(client: Client, purchase_id: str, price: str) -> None:
    """A price schedule, which is how a non-consumable is priced: a base territory and one price.

    One request creates both. The price does not exist yet, so it travels in `included` and is
    pointed at by a `${...}` placeholder id, which Apple resolves on the way in.
    """
    point = price_point(client, f"{PURCHASES}/{purchase_id}/pricePoints", price)
    client.expect("POST", "/v1/inAppPurchasePriceSchedules", {
        "data": {
            "type": "inAppPurchasePriceSchedules",
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": purchase_id}},
                "baseTerritory": {"data": {"type": "territories", "id": BASE_TERRITORY}},
                "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price}"}]}}},
        "included": [{
            "type": "inAppPurchasePrices",
            "id": "${price}",
            "attributes": {"startDate": None},
            "relationships": {"inAppPurchasePricePoint": {
                "data": {"type": "inAppPurchasePricePoints", "id": point}}}}]})


def purchase_availability(client: Client, purchase_id: str) -> int:
    """Everywhere, and everywhere Apple adds later.

    A subscription takes `availableInAllTerritories` when it is created. A non-consumable has no
    such attribute and wants the list instead, so the list is fetched: about a hundred and
    seventy-five ids, in one request, sent back in one more.
    """
    existing = client.call("GET", f"{PURCHASES}/{purchase_id}/inAppPurchaseAvailability")[1]
    if existing.get("data"):
        return total(client, "/v1/inAppPurchaseAvailabilities/"
                             f"{existing['data']['id']}/availableTerritories?limit=200")
    territories = [{"type": "territories", "id": entry["id"]}
                   for entry in client.collection("/v1/territories?limit=200")]
    client.expect("POST", "/v1/inAppPurchaseAvailabilities", {"data": {
        "type": "inAppPurchaseAvailabilities",
        "attributes": {"availableInNewTerritories": True},
        "relationships": {
            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": purchase_id}},
            "availableTerritories": {"data": territories}}}})
    return len(territories)


# ---------------------------------------------------------------------------


def main() -> int:
    document = configuration()
    say(f"The products of {STOREKIT.name}, in App Store Connect")
    check_copy()

    client = Client()
    app = app_record(client)
    good("app record", f"{app['attributes']['name']} ({app['id']})")

    print(f"\n{BOLD}Subscription group{RESET}")
    definition = document["subscriptionGroups"][0]
    group_id = group(client, app["id"], definition["name"])
    group_localizations(client, group_id)

    incomplete = []

    print(f"\n{BOLD}Subscriptions{RESET}")
    for spec in definition["subscriptions"]:
        identifier, fresh = subscription(client, group_id, spec)
        owner = f"/v1/subscriptions/{identifier}"
        locales = subscription_localizations(client, identifier, plan(spec["productID"]))
        notes = ["created" if fresh else "on record",
                 spec["recurringSubscriptionPeriod"], f"{locales} locales"]
        if fresh:
            subscription_price(client, identifier, spec["displayPrice"])
        priced = total(client, f"{owner}/prices?limit=200")
        notes.append(f"{spec['displayPrice']} in {priced} territories" if priced > 0
                     else f"{spec['displayPrice']}, territories unreadable")
        offer = introductory_offer(client, identifier, spec)
        if offer:
            notes.append(offer)
        notes.append(review_screenshot(client, owner, identifier, SUBSCRIPTION_SHOT))
        if not report(spec["productID"], notes, state(client, owner)):
            incomplete.append(spec["productID"])

    print(f"\n{BOLD}One time purchases{RESET}")
    for spec in document.get("products", []):
        if spec.get("type") != "NonConsumable":
            warn(f"{spec['productID']} is a {spec.get('type')}, which this script does not create")
            continue
        identifier, fresh = purchase(client, app["id"], spec)
        owner = f"{PURCHASES}/{identifier}"
        locales = purchase_localizations(client, identifier, plan(spec["productID"]))
        notes = ["created" if fresh else "on record", f"{locales} locales"]
        if fresh:
            purchase_price(client, identifier, spec["displayPrice"])
        available = purchase_availability(client, identifier)
        notes.append(f"{spec['displayPrice']} in {available} territories" if available > 0
                     else f"{spec['displayPrice']}, territories unreadable")
        notes.append(review_screenshot(client, owner, identifier, PURCHASE_SHOT))
        if not report(spec["productID"], notes, state(client, owner)):
            incomplete.append(spec["productID"])

    print()
    if incomplete:
        warn(f"App Store Connect still calls {len(incomplete)} of these incomplete.\n")
        if not REVIEW_SHOT.is_file():
            print(f"  {REVIEW_SHOT.relative_to(ROOT)} does not exist, and Apple asks for a picture")
            print("  of the purchase screen with every product. Capture it with:\n")
            print("    scripts/shots.sh --review\n")
        print("  Then re-run this script: it sends only what is missing.")
        return 1

    say("Every product is ready to submit with the build")
    print("  They go for review attached to a version, so nothing more is needed here until")
    print("  scripts/publish.py has made the version to attach them to.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
