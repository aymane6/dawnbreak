#!/usr/bin/env python3
"""Everything the Release build needs to sign, from the App Store Connect API alone.

    python3 scripts/provision.py

Creates, or reuses, and then reports:

    two App IDs                 com.aymbam.dawnbreak and com.aymbam.dawnbreak.widget
    the App Groups capability   on both of them
    one distribution certificate  Apple Distribution, imported into the login keychain
    two App Store profiles      "Dawnbreak App Store", "Dawnbreak Widget App Store",
                                installed where Xcode looks for them

which are exactly the names `project.yml` and `Configuration/ExportOptions.plist` name for manual
Release signing. Run it once per machine, and again whenever the certificate or a profile expires.

This exists because `xcodebuild -allowProvisioningUpdates` cannot do it here. That flag talks to
developerservices2.apple.com, and that host answers an App Store Connect API key with
"Authentication failed: Make sure a bearer token was provided, it is properly configured and signed,
and it has not expired" whatever the token's audience, lifetime or scope: it wants the session an
interactive Apple ID login produces, and no Apple ID is signed in on this machine. The public API at
api.appstoreconnect.apple.com does accept the key, and everything listed above can be made through
it, so that is what this does.

One thing cannot: the App Group itself. The public API has no appGroups resource, so
`group.com.aymbam.dawnbreak` has to be created once by a human at developer.apple.com and assigned
to both App IDs. A profile made before that carries an empty group list, and the archive then fails
with four errors about a provisioning profile that mention the group only in passing. This script
reads the profiles it just made and says so in one line instead.

Credentials come from the environment and are never in the repository:

    export ASC_KEY_ID=XXXXXXXXXX
    export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

with the private key at ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8. The JWT is signed
by openssl rather than a Python library, so this needs nothing installed that Xcode does not already
bring. The certificate's own private key is generated locally, goes into the login keychain, and is
written nowhere else.

Exit code is 1 if the Release build could not be signed with what is now in place.
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
import plistlib
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = "https://api.appstoreconnect.apple.com"
TEAM = "2Y97DK7UM4"
APP_GROUP = "group.com.aymbam.dawnbreak"
CERTIFICATE_TYPE = "DISTRIBUTION"
PROFILE_TYPE = "IOS_APP_STORE"
# Where Xcode reads installed profiles from. `xcodebuild` will not fetch one for a manually signed
# target unless it is already here, which is the whole point of installing them.
PROFILE_DIRECTORY = Path.home() / "Library" / "Developer" / "Xcode" / "UserData" / "Provisioning Profiles"
# The same folders scripts/release.sh searches, in the same order, so a key that works for one works
# for the other.
KEY_FOLDERS = ("./private_keys", "~/private_keys", "~/.private_keys", "~/.appstoreconnect/private_keys")

# name in the portal, bundle id, profile name. The profile names are the contract with project.yml.
TARGETS = (
    ("Dawnbreak", "com.aymbam.dawnbreak", "Dawnbreak App Store"),
    ("Dawnbreak Widget", "com.aymbam.dawnbreak.widget", "Dawnbreak Widget App Store"),
)

BOLD, GREEN, YELLOW, RED, RESET = "\033[1m", "\033[1;32m", "\033[1;33m", "\033[1;31m", "\033[0m"


def say(message: str) -> None:
    print(f"\033[1;36m==>{RESET} {message}")


def good(label: str, detail: str = "") -> None:
    print(f"  {GREEN}✓{RESET} {label:<34} {detail}")


def bad(label: str) -> None:
    print(f"  {RED}✗{RESET} {label}")


def die(message: str) -> None:
    print(f"{RED}provision:{RESET} {message}", file=sys.stderr)
    raise SystemExit(1)


def run(*command: str, stdin: bytes | None = None) -> bytes:
    """A subprocess that fails loudly. openssl and security both report on stderr."""
    result = subprocess.run(command, input=stdin, capture_output=True, check=False)
    if result.returncode != 0:
        die(f"{command[0]} failed: {result.stderr.decode(errors='replace').strip()}")
    return result.stdout


# ---------------------------------------------------------------------------
# The API
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


class Client:
    def __init__(self) -> None:
        self.key_id, self.issuer, self.key_path = credentials()

    def call(self, method: str, path: str, body: dict | None = None) -> tuple[int, dict]:
        request = urllib.request.Request(
            BASE + path,
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
            detail = "; ".join(e.get("detail", "") for e in payload.get("errors", [])) or json.dumps(payload)[:300]
            die(f"{method} {path} answered {status}: {detail}")
        return payload


# ---------------------------------------------------------------------------
# App IDs and their capabilities
# ---------------------------------------------------------------------------


def app_identifier(client: Client, name: str, identifier: str) -> str:
    found = client.expect("GET", f"/v1/bundleIds?filter[identifier]={identifier}&limit=200")["data"]
    # filter[identifier] is a prefix-free exact match on Apple's side, but the app's own id is a
    # prefix of the widget's, so confirm rather than trust the first row.
    for entry in found:
        if entry["attributes"]["identifier"] == identifier:
            good("App ID", f"{identifier} ({entry['id']})")
            return entry["id"]
    created = client.expect("POST", "/v1/bundleIds", {"data": {"type": "bundleIds", "attributes": {
        "identifier": identifier, "name": name, "platform": "IOS", "seedId": TEAM}}})
    good("App ID registered", f"{identifier} ({created['data']['id']})")
    return created["data"]["id"]


def app_groups_capability(client: Client, resource_id: str) -> None:
    """The capability, not the group. Without it the profile has no group list at all."""
    # No `limit` on this one: the relationship rejects the parameter with a 400.
    existing = client.expect("GET", f"/v1/bundleIds/{resource_id}/bundleIdCapabilities")["data"]
    if any(entry["attributes"]["capabilityType"] == "APP_GROUPS" for entry in existing):
        good("App Groups capability", "already enabled")
        return
    client.expect("POST", "/v1/bundleIdCapabilities", {"data": {"type": "bundleIdCapabilities",
        "attributes": {"capabilityType": "APP_GROUPS", "settings": []},
        "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": resource_id}}}}})
    good("App Groups capability", "enabled")


# ---------------------------------------------------------------------------
# The certificate
# ---------------------------------------------------------------------------


def local_identities() -> set[str]:
    """The SHA-1 hashes `security` will sign with, which is what makes a portal certificate usable.

    A certificate in the portal whose private key is not in this keychain is not a credential, it is
    a name. The hash printed by find-identity is the SHA-1 of the certificate, so it can be compared
    against what the API hands back without downloading anything.
    """
    listing = subprocess.run(["security", "find-identity", "-v", "-p", "codesigning"],
                             capture_output=True, text=True, check=False).stdout
    return set(re.findall(r"\b([0-9A-F]{40})\b", listing))


def certificate(client: Client) -> tuple[str, str]:
    usable = local_identities()
    for entry in client.expect("GET", "/v1/certificates?limit=200")["data"]:
        attributes = entry["attributes"]
        if attributes["certificateType"] != CERTIFICATE_TYPE:
            continue
        fingerprint = hashlib.sha1(base64.b64decode(attributes["certificateContent"])).hexdigest().upper()
        if fingerprint in usable:
            good("distribution certificate", f"{attributes['name']}, to {attributes['expirationDate'][:10]}")
            return entry["id"], attributes["name"]
    return create_certificate(client)


def create_certificate(client: Client) -> tuple[str, str]:
    """A key and a CSR here, a certificate there, both halves into the keychain.

    `security import -A` rather than `-T /usr/bin/codesign`: without it the first signature blocks on
    a keychain dialog that nobody is there to answer, which turns an unattended archive into a
    twenty-minute hang. The key is the team's distribution key on the machine that owns the account.
    """
    with tempfile.TemporaryDirectory(prefix="dawnbreak-signing.") as scratch:
        folder = Path(scratch)
        key, csr, p12 = folder / "dist.key", folder / "dist.csr", folder / "dist.p12"
        run("openssl", "req", "-new", "-newkey", "rsa:2048", "-nodes",
            "-keyout", str(key), "-out", str(csr), "-subj", "/CN=Dawnbreak Distribution/C=US")
        created = client.expect("POST", "/v1/certificates", {"data": {"type": "certificates",
            "attributes": {"certificateType": CERTIFICATE_TYPE, "csrContent": csr.read_text()}}})
        attributes = created["data"]["attributes"]
        (folder / "dist.cer").write_bytes(base64.b64decode(attributes["certificateContent"]))
        run("openssl", "x509", "-inform", "DER", "-in", str(folder / "dist.cer"), "-out", str(folder / "dist.pem"))
        run("openssl", "pkcs12", "-export", "-inkey", str(key), "-in", str(folder / "dist.pem"),
            "-out", str(p12), "-passout", "pass:", "-name", attributes["name"])
        run("security", "import", str(p12), "-k", str(Path.home() / "Library/Keychains/login.keychain-db"),
            "-P", "", "-f", "pkcs12", "-A")
    fingerprint = hashlib.sha1(base64.b64decode(attributes["certificateContent"])).hexdigest().upper()
    if fingerprint not in local_identities():
        die("the certificate was created but did not become a usable identity in the login keychain")
    good("distribution certificate created", f"{attributes['name']}, to {attributes['expirationDate'][:10]}")
    return created["data"]["id"], attributes["name"]


# ---------------------------------------------------------------------------
# The profiles
# ---------------------------------------------------------------------------


def entitlements(profile_content: str) -> dict:
    """The plist inside a .mobileprovision, which is a CMS envelope wrapped around it."""
    raw = base64.b64decode(profile_content)
    start, end = raw.index(b"<?xml"), raw.index(b"</plist>") + len(b"</plist>")
    return plistlib.loads(raw[start:end])


def profile(client: Client, name: str, bundle_resource: str, certificate_id: str) -> tuple[dict, bool]:
    """The named App Store profile, remade if what is on record cannot sign this build.

    Remade rather than reused whenever it does not carry the app group: a profile is a snapshot of
    the App ID's capabilities at the moment it was issued, so the one made before the group existed
    stays wrong forever and is the trap this function exists to avoid.
    """
    for entry in client.expect("GET", "/v1/profiles?limit=200")["data"]:
        if entry["attributes"]["name"] != name:
            continue
        plist = entitlements(entry["attributes"]["profileContent"])
        healthy = (entry["attributes"]["profileState"] == "ACTIVE"
                   and APP_GROUP in plist["Entitlements"].get("com.apple.security.application-groups", []))
        if healthy:
            return install(entry, plist), True
        client.expect("DELETE", f"/v1/profiles/{entry['id']}")
        break

    created = client.expect("POST", "/v1/profiles", {"data": {"type": "profiles",
        "attributes": {"name": name, "profileType": PROFILE_TYPE},
        "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle_resource}},
                          "certificates": {"data": [{"type": "certificates", "id": certificate_id}]}}}})
    plist = entitlements(created["data"]["attributes"]["profileContent"])
    groups = plist["Entitlements"].get("com.apple.security.application-groups", [])
    return install(created["data"], plist), APP_GROUP in groups


def install(entry: dict, plist: dict) -> dict:
    PROFILE_DIRECTORY.mkdir(parents=True, exist_ok=True)
    destination = PROFILE_DIRECTORY / f"{plist['UUID']}.mobileprovision"
    destination.write_bytes(base64.b64decode(entry["attributes"]["profileContent"]))
    return plist


# ---------------------------------------------------------------------------


def main() -> int:
    client = Client()
    say(f"Provisioning through the App Store Connect API (key {client.key_id})")

    print(f"\n{BOLD}App IDs{RESET}")
    resources = {}
    for name, identifier, _ in TARGETS:
        resources[identifier] = app_identifier(client, name, identifier)
        app_groups_capability(client, resources[identifier])

    print(f"\n{BOLD}Certificate{RESET}")
    certificate_id, certificate_name = certificate(client)

    print(f"\n{BOLD}Profiles{RESET}")
    missing_group = []
    for _, identifier, profile_name in TARGETS:
        plist, has_group = profile(client, profile_name, resources[identifier], certificate_id)
        detail = f"{plist['UUID']}, to {plist['ExpirationDate'].date()}"
        if has_group:
            good(profile_name, detail)
        else:
            bad(f"{profile_name}: installed, but authorises no app group ({detail})")
            missing_group.append(profile_name)

    print()
    if missing_group:
        print(f"{YELLOW}provision:{RESET} the profiles cannot sign this app yet.\n")
        print(f"  {APP_GROUP} does not exist in the developer portal, and the App Store Connect API")
        print("  has no endpoint that can create one. Once, by hand, signed in as the account holder:\n")
        print("    developer.apple.com/account → Identifiers → App Groups → +")
        print(f"      Description: Dawnbreak    Identifier: {APP_GROUP}")
        print("    Identifiers → App IDs → com.aymbam.dawnbreak → App Groups → Edit → tick it")
        print("    the same for com.aymbam.dawnbreak.widget\n")
        print("  Then re-run this script: it deletes the empty profiles and issues them again.")
        return 1

    say(f"Ready to archive: {certificate_name}, {len(TARGETS)} profiles installed")
    print(f"  Signing identity and profile names match project.yml and Configuration/ExportOptions.plist.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
