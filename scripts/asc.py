#!/usr/bin/env python3
"""The App Store Connect API, and the token it wants, for the scripts that talk to it.

Imported by `provision.py` (signing assets), `iap.py` (the three products) and `publish.py` (the
listing and the screenshots). Not runnable on its own, and deliberately dependency-free: the JWT is
signed by `openssl`, so nothing here needs a Python package that Xcode does not already bring.

Credentials come from the environment and are never in the repository:

    export ASC_KEY_ID=XXXXXXXXXX
    export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

with the private key at ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8, which is where
altool looks and which .gitignore refuses to track.

One thing worth knowing before reaching for this: the key authenticates to
api.appstoreconnect.apple.com and to nothing else. developerservices2.apple.com, which is the host
`xcodebuild -allowProvisioningUpdates` uses and the only one with an App Group resource, answers the
same key 401 whatever the token's audience, lifetime or scope. See the header of `provision.py`.
"""

from __future__ import annotations

import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = "https://api.appstoreconnect.apple.com"
TEAM = "2Y97DK7UM4"
BUNDLE_ID = "com.aymbam.dawnbreak"

# The same folders scripts/release.sh searches, in the same order, so a key that works for one works
# for all of them.
KEY_FOLDERS = ("./private_keys", "~/private_keys", "~/.private_keys", "~/.appstoreconnect/private_keys")

BOLD, GREEN, YELLOW, RED, CYAN, RESET = (
    "\033[1m", "\033[1;32m", "\033[1;33m", "\033[1;31m", "\033[1;36m", "\033[0m")

# So every message names the script the reader actually ran, not this module.
WHO = Path(sys.argv[0]).stem or "asc"


def say(message: str) -> None:
    print(f"{CYAN}==>{RESET} {message}")


def good(label: str, detail: str = "") -> None:
    print(f"  {GREEN}✓{RESET} {label:<34} {detail}")


def bad(label: str) -> None:
    print(f"  {RED}✗{RESET} {label}")


def warn(message: str) -> None:
    print(f"{YELLOW}{WHO}:{RESET} {message}")


def die(message: str) -> None:
    print(f"{RED}{WHO}:{RESET} {message}", file=sys.stderr)
    raise SystemExit(1)


def run(*command: str, stdin: bytes | None = None) -> bytes:
    """A subprocess that fails loudly. openssl and security both report on stderr."""
    result = subprocess.run(command, input=stdin, capture_output=True, check=False)
    if result.returncode != 0:
        die(f"{command[0]} failed: {result.stderr.decode(errors='replace').strip()}")
    return result.stdout


# ---------------------------------------------------------------------------
# The token
# ---------------------------------------------------------------------------


def credentials() -> tuple[str, str, Path]:
    key_id = os.environ.get("ASC_KEY_ID")
    issuer = os.environ.get("ASC_ISSUER_ID")
    if not key_id or not issuer:
        die("set ASC_KEY_ID and ASC_ISSUER_ID (App Store Connect, Users and Access, Integrations)")
    for folder in KEY_FOLDERS:
        candidate = Path(folder).expanduser() / f"AuthKey_{key_id}.p8"
        if candidate.is_file():
            return key_id, issuer, candidate
    die(f"no AuthKey_{key_id}.p8 in ~/.appstoreconnect/private_keys/")
    raise AssertionError  # unreachable, for the type checker


def base64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def raw_signature(der: bytes) -> bytes:
    """ECDSA in DER, which is what openssl emits, to the fixed 64 bytes JOSE wants.

    DER wraps r and s as INTEGERs: each is minimally encoded, so it may carry a leading zero byte
    to stay positive, or be shorter than 32 bytes. ES256 wants both padded to exactly 32.
    """
    if der[0] != 0x30:
        die("openssl did not produce a DER signature")
    index = 2 if der[1] < 0x80 else 3
    parts = []
    for _ in range(2):
        if der[index] != 0x02:
            die("openssl did not produce a DER signature")
        length = der[index + 1]
        parts.append(der[index + 2 : index + 2 + length].lstrip(b"\x00").rjust(32, b"\x00"))
        index += 2 + length
    return b"".join(parts)


def token(key_id: str, issuer: str, key_path: Path) -> str:
    """ES256, signed by openssl, valid for ten minutes. Apple's ceiling is twenty."""
    now = int(time.time())
    header = base64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    claims = base64url(json.dumps(
        {"iss": issuer, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
    ).encode())
    signing_input = f"{header}.{claims}".encode()
    der = run("openssl", "dgst", "-sha256", "-sign", str(key_path), stdin=signing_input)
    return f"{header}.{claims}.{base64url(raw_signature(der))}"


# ---------------------------------------------------------------------------
# The calls
# ---------------------------------------------------------------------------


class Client:
    """One token per request, because a screenshot run outlives any token's lifetime.

    Minting is a single openssl call and Apple has no per-token cost, so nothing is cached: a
    ninety-minute upload of seventy-two files would otherwise die halfway through on a 401.
    """

    def __init__(self) -> None:
        self.key_id, self.issuer, self.key_path = credentials()

    def call(self, method: str, path: str, body: dict | None = None) -> tuple[int, dict]:
        request = urllib.request.Request(
            path if path.startswith("http") else BASE + path,
            method=method,
            data=json.dumps(body).encode() if body else None,
            headers={
                "Authorization": f"Bearer {token(self.key_id, self.issuer, self.key_path)}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request) as response:
                return response.status, json.loads(response.read() or b"{}")
        except urllib.error.HTTPError as error:
            raw = error.read()
            try:
                return error.code, json.loads(raw)
            except json.JSONDecodeError:
                return error.code, {"raw": raw.decode(errors="replace")[:400]}

    def expect(self, method: str, path: str, body: dict | None = None) -> dict:
        status, payload = self.call(method, path, body)
        if status >= 300:
            die(f"{method} {path} answered {status}: {problem(payload)}")
        return payload

    def collection(self, path: str) -> list[dict]:
        """Every page of a collection, flattened.

        Apple caps `limit` at 200 and hands back `links.next` rather than a total, so a twelve
        locale listing with six screenshots each is several pages of one relationship.
        """
        rows: list[dict] = []
        while path:
            payload = self.expect("GET", path)
            rows.extend(payload.get("data", []))
            path = payload.get("links", {}).get("next", "")
        return rows

    def upload(self, operations: list[dict], blob: bytes) -> None:
        """The bytes of a reserved asset, to the pre-signed URLs Apple hands back.

        No Authorization header on these: the signature is in the URL, and adding a bearer token
        makes S3 reject the whole request. Only the headers Apple names are sent.
        """
        for operation in operations:
            offset, length = operation.get("offset", 0), operation.get("length", len(blob))
            request = urllib.request.Request(
                operation["url"],
                method=operation.get("method", "PUT"),
                data=blob[offset : offset + length],
                headers={header["name"]: header["value"]
                         for header in operation.get("requestHeaders", [])},
            )
            try:
                with urllib.request.urlopen(request) as response:
                    if response.status >= 300:
                        die(f"the upload answered {response.status}")
            except urllib.error.HTTPError as error:
                die(f"the upload answered {error.code}: {error.read().decode(errors='replace')[:200]}")


def problem(payload: dict) -> str:
    """Apple's error envelope, in one line. `detail` is the useful field; `title` is generic.

    `meta.associatedErrors` is walked, because a refused submission keeps its reasons there and only
    there: the top level says "This resource cannot be reviewed, please check associated errors to
    see why", and each reason underneath names an attribute on some other resource entirely, with the
    path it belongs to. Dropping them turns the most informative answer this API gives into the least.
    """
    errors = payload.get("errors", [])
    if not errors:
        return json.dumps(payload)[:300]
    lines = []
    for entry in errors:
        pointer = entry.get("source", {}).get("pointer")
        text = entry.get("detail") or entry.get("title", "")
        lines.append(f"{text} ({pointer})" if pointer else text)
        for path, associated in (entry.get("meta", {}).get("associatedErrors") or {}).items():
            lines += [f"{path} {nested.get('detail') or nested.get('title', '')}"
                      for nested in associated]
    return "; ".join(lines)


def app_record(client: Client, bundle_id: str = BUNDLE_ID) -> dict:
    """The app record, or the reason there is none and what to do about it.

    `POST /v1/apps` is not allowed for an API key at all: Apple answers "The resource 'apps' does
    not allow 'CREATE'". So this is the one thing every script here needs and none of them can
    make, and it fails with the click path rather than with a 404 forty lines later.
    """
    for entry in client.collection(f"/v1/apps?filter[bundleId]={bundle_id}&limit=200"):
        if entry["attributes"]["bundleId"] == bundle_id:
            return entry
    die(f"there is no app record for {bundle_id} yet, and an API key cannot create one:\n"
        f"  POST /v1/apps answers \"The resource 'apps' does not allow 'CREATE'\".\n\n"
        "  Once, by hand, signed in at appstoreconnect.apple.com:\n"
        "    Apps → + → New App\n"
        "      Platform iOS, Bundle ID Dawnbreak (com.aymbam.dawnbreak),\n"
        "      Name from metadata/en-US/name.txt, Primary Language English (U.S.),\n"
        "      SKU dawnbreak-1, Full Access\n\n"
        "  Then re-run this script.")
    raise AssertionError  # unreachable, for the type checker
