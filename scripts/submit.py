#!/usr/bin/env python3
"""Sends the staged version to Apple. The last call, and the only one that cannot be undone.

    export ASC_KEY_ID=XXXXXXXXXX
    export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    python3 scripts/submit.py             # says what it would send, and stops
    python3 scripts/submit.py --send      # sends it

Separate from `scripts/publish.py` on purpose. That script writes the listing, which is editable
until the moment this one runs; this one hands the app to reviewers under the account holder's own
declarations, and a submitted review submission cannot be un-submitted, only cancelled, and
cancelling one is documented to strand anything else that was in it.

For most of this project's life there was no such script, and the note in `publish.py` said sending
was a person's act. That was true for a reason that no longer holds: while the app had three products,
`POST /v1/reviewSubmissionItems` could not carry them (no relationship for `subscription`, none for
`inAppPurchaseV2`, both 409 on 2026-09-03), so a submission built through the API would have gone to
Apple without them and been rejected for products "not found in the submitted binary". With nothing to
sell, the draft holds one item and the API can express all of it, so the button is legitimately here.

What it will not do is send a draft it has not checked. Every refusal below is something Apple would
have answered with days later, or worse, accepted.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from asc import BOLD, Client, RESET, app_record, bad, die, good, problem, say

# Apple reviews a version in one of these states and refuses one in any other. `READY_FOR_REVIEW` is
# what a staged-but-unsent version reads as, and is the expected value here.
SENDABLE = {"READY_FOR_REVIEW", "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
            "METADATA_REJECTED", "INVALID_BINARY"}


def draft(client: Client, app_id: str) -> dict:
    """The one un-submitted review submission, or the reason there is nothing to send."""
    drafts = [entry for entry in client.collection(f"/v1/apps/{app_id}/reviewSubmissions?limit=50")
              if not entry["attributes"]["submittedDate"]]
    if not drafts:
        die("there is no un-submitted draft. Run `python3 scripts/publish.py` first: it writes the\n"
            "  listing and stages the version, which is what this script sends.")
    if len(drafts) > 1:
        die(f"there are {len(drafts)} un-submitted drafts, which is one too many to guess between:\n"
            + "\n".join(f"    {entry['id']}  {entry['attributes']['state']}" for entry in drafts))
    return drafts[0]


def contents(client: Client, submission_id: str) -> list[dict]:
    """What the draft actually holds, resolved to versions rather than item ids."""
    return client.collection(f"/v1/reviewSubmissions/{submission_id}/items"
                             "?include=appStoreVersion&limit=50")


def main() -> int:
    parser = argparse.ArgumentParser(description="Sends the staged App Store version for review.")
    parser.add_argument("--send", action="store_true",
                        help="actually send it; without this the script only reports")
    arguments = parser.parse_args()

    client = Client()
    app = app_record(client)
    say(f"{app['attributes']['name']} ({app['id']})")

    print(f"\n{BOLD}The draft{RESET}")
    submission = draft(client, app["id"])
    good("draft", f"{submission['id']}  {submission['attributes']['state']}")

    items = contents(client, submission["id"])
    if not items:
        die("the draft is empty, so sending it would ask Apple to review nothing. Re-run\n"
            "  `python3 scripts/publish.py`, which adds the version and reports what it is missing.")
    good("items", f"{len(items)}")

    # Every item, checked before anything is sent. A draft with a version in the wrong state, or with
    # no build, is a rejection Apple can already see; there is no reason to spend a queue slot on it.
    ready = True
    for item in items:
        related = (item.get("relationships", {}).get("appStoreVersion", {}).get("data") or {})
        if not related:
            bad(f"item {item['id']} is not an app version, and this script only knows versions")
            ready = False
            continue
        version = client.expect("GET", f"/v1/appStoreVersions/{related['id']}")["data"]["attributes"]
        number, state = version["versionString"], version["appStoreState"]
        if state not in SENDABLE:
            bad(f"version {number} is {state}, which Apple will not take")
            ready = False
        else:
            good(f"version {number}", f"{state}, releaseType={version['releaseType']}")

        build = client.expect("GET", f"/v1/appStoreVersions/{related['id']}/build")["data"]
        if not build:
            bad(f"version {number} has no build attached")
            ready = False
        elif build["attributes"]["processingState"] != "VALID":
            bad(f"build {build['attributes']['version']} is "
                f"{build['attributes']['processingState']}, not VALID")
            ready = False
        else:
            good(f"build {build['attributes']['version']}", "VALID")

    if not ready:
        die("nothing was sent.")

    if not arguments.send:
        print()
        say("This is what `--send` would hand to Apple. Nothing has been sent.")
        return 0

    print(f"\n{BOLD}Sending{RESET}")
    status, payload = client.call("PATCH", f"/v1/reviewSubmissions/{submission['id']}", {"data": {
        "type": "reviewSubmissions",
        "id": submission["id"],
        "attributes": {"submitted": True}}})
    if status >= 300:
        # The associated errors are the whole value of this answer: the top level says only that the
        # resource cannot be reviewed, and each reason underneath names the field that is missing and
        # the resource it belongs to. `problem` walks them.
        die("Apple refused the submission:\n  " + problem(payload).replace("; ", "\n  "))

    attributes = payload["data"]["attributes"]
    good("submitted", f"{attributes['state']}  {attributes.get('submittedDate') or 'no date yet'}")

    print()
    say("It is with Apple. The listing is frozen until they answer.")
    print("  Watch it at App Store Connect → Dawnbreak → Distribution, or re-run this script,")
    print("  which will now say there is no un-submitted draft, because there is not.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
