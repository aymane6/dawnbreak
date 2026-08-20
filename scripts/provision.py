#!/usr/bin/env python3
"""Everything the Release build needs to sign, from the App Store Connect API alone.

    python3 scripts/provision.py

Creates, or reuses, and then reports:

    two App IDs                 com.aymbam.dawnbreak and com.aymbam.dawnbreak.widget
    the App Groups capability   on both of them
    a distribution certificate  Apple Distribution, imported into the login keychain, unless one
                                this keychain can already sign with exists
    two App Store profiles      "Dawnbreak App Store", "Dawnbreak Widget App Store", carrying every
                                usable distribution certificate rather than one, and installed where
                                Xcode looks for them

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

with the private key at ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8. The client and its
token are in scripts/asc.py, which signs with openssl rather than a Python library so that this
needs nothing installed that Xcode does not already bring. The certificate's own private key is
generated locally, goes into the login keychain, and is written nowhere else.

Exit code is 1 if the Release build could not be signed with what is now in place.
"""

from __future__ import annotations

import base64
import hashlib
import plistlib
import re
import subprocess
import tempfile
from pathlib import Path

from asc import BOLD, Client, RESET, TEAM, bad, die, good, run, say, warn

APP_GROUP = "group.com.aymbam.dawnbreak"
CERTIFICATE_TYPE = "DISTRIBUTION"
PROFILE_TYPE = "IOS_APP_STORE"
# Where Xcode reads installed profiles from. `xcodebuild` will not fetch one for a manually signed
# target unless it is already here, which is the whole point of installing them.
PROFILE_DIRECTORY = Path.home() / "Library" / "Developer" / "Xcode" / "UserData" / "Provisioning Profiles"

# name in the portal, bundle id, profile name. The profile names are the contract with project.yml.
TARGETS = (
    ("Dawnbreak", "com.aymbam.dawnbreak", "Dawnbreak App Store"),
    ("Dawnbreak Widget", "com.aymbam.dawnbreak.widget", "Dawnbreak Widget App Store"),
)


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


def certificates(client: Client) -> tuple[list[str], set[str], str]:
    """Every distribution certificate this keychain can sign with, not just the first one found.

    Returns the API ids to put in a profile, their SHA-1 hashes to check a profile against, and a
    name to print.

    All of them, because this team has two and both are called "Apple Distribution: Aymane
    BAMHAMED": one Xcode made, one `create_certificate` below made. `CODE_SIGN_IDENTITY` in
    project.yml names an identity, and a name does not choose between two identities that share it,
    so which one signs is Xcode's decision. A profile carrying only the other one fails the archive
    with `Provisioning profile "Dawnbreak App Store" doesn't include signing certificate` after the
    tests have already run. Putting every usable one in every profile is what Xcode's own automatic
    signing does, and it makes the choice stop mattering.
    """
    usable = local_identities()
    identifiers, fingerprints, name = [], set(), ""
    for entry in client.expect("GET", "/v1/certificates?limit=200")["data"]:
        attributes = entry["attributes"]
        if attributes["certificateType"] != CERTIFICATE_TYPE:
            continue
        fingerprint = hashlib.sha1(base64.b64decode(attributes["certificateContent"])).hexdigest().upper()
        if fingerprint not in usable:
            continue
        identifiers.append(entry["id"])
        fingerprints.add(fingerprint)
        name = attributes["name"]
        good("distribution certificate", f"{name}, to {attributes['expirationDate'][:10]}")

    if not identifiers:
        return create_certificate(client)
    return identifiers, fingerprints, name


def create_certificate(client: Client) -> tuple[list[str], set[str], str]:
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
    return [created["data"]["id"]], {fingerprint}, attributes["name"]


# ---------------------------------------------------------------------------
# The profiles
# ---------------------------------------------------------------------------


def entitlements(profile_content: str) -> dict:
    """The plist inside a .mobileprovision, which is a CMS envelope wrapped around it."""
    raw = base64.b64decode(profile_content)
    start, end = raw.index(b"<?xml"), raw.index(b"</plist>") + len(b"</plist>")
    return plistlib.loads(raw[start:end])


def signers(plist: dict) -> set[str]:
    """The SHA-1 of every certificate a profile authorises, which is what Xcode matches against."""
    return {hashlib.sha1(certificate).hexdigest().upper()
            for certificate in plist.get("DeveloperCertificates", [])}


def profile(client: Client, name: str, bundle_resource: str,
            certificate_ids: list[str], fingerprints: set[str]) -> tuple[dict, list[str]]:
    """The named App Store profile, remade if what is on record cannot sign this build.

    Returns the installed profile and what is still wrong with it, empty when it can sign.

    A profile is a snapshot of the App ID's capabilities and of the certificates chosen at the moment
    it was issued, and neither can be edited afterwards. So both are checked and a profile that fails
    either is deleted and reissued rather than reused: the one made before the app group existed
    stays wrong forever, and so does the one made when only one of the two distribution certificates
    was picked.
    """
    for entry in client.expect("GET", "/v1/profiles?limit=200")["data"]:
        if entry["attributes"]["name"] != name:
            continue
        plist = entitlements(entry["attributes"]["profileContent"])
        healthy = (entry["attributes"]["profileState"] == "ACTIVE"
                   and APP_GROUP in plist["Entitlements"].get("com.apple.security.application-groups", [])
                   and fingerprints <= signers(plist))
        if healthy:
            return install(entry, plist), []
        client.expect("DELETE", f"/v1/profiles/{entry['id']}")
        break

    created = client.expect("POST", "/v1/profiles", {"data": {"type": "profiles",
        "attributes": {"name": name, "profileType": PROFILE_TYPE},
        "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle_resource}},
                          "certificates": {"data": [{"type": "certificates", "id": identifier}
                                                    for identifier in certificate_ids]}}}})
    plist = entitlements(created["data"]["attributes"]["profileContent"])

    wrong = []
    if APP_GROUP not in plist["Entitlements"].get("com.apple.security.application-groups", []):
        wrong.append("authorises no app group")
    orphans = fingerprints - signers(plist)
    if orphans:
        # Apple accepted the ids and handed back a profile without them, which no amount of
        # re-running fixes. Naming the hash is the only way to tell which identity to stop using.
        wrong.append(f"omits {len(orphans)} usable signing certificate(s): {', '.join(sorted(orphans))}")
    return install(created["data"], plist), wrong


def install(entry: dict, plist: dict) -> dict:
    """Write the profile where Xcode reads them, and take every older namesake away from it.

    The eviction is the point. Profiles are stored one file per UUID, `xcodebuild` resolves
    `PROVISIONING_PROFILE_SPECIFIER` by name, and reissuing changes the UUID: four rounds of fixing
    a profile leave four files all called "Dawnbreak App Store", three of them the broken ones this
    script just replaced. Which one Xcode then picks is not defined, so an archive can fail on a
    profile that was deleted server-side an hour earlier and the error says nothing about that.
    """
    PROFILE_DIRECTORY.mkdir(parents=True, exist_ok=True)
    destination = PROFILE_DIRECTORY / f"{plist['UUID']}.mobileprovision"
    destination.write_bytes(base64.b64decode(entry["attributes"]["profileContent"]))

    for installed in PROFILE_DIRECTORY.glob("*.mobileprovision"):
        if installed == destination:
            continue
        try:
            other = entitlements(base64.b64encode(installed.read_bytes()).decode())
        except (ValueError, plistlib.InvalidFileException):
            continue  # not ours to judge: an unreadable profile belongs to some other tool
        if other.get("Name") == plist["Name"]:
            installed.unlink()
    return plist


# ---------------------------------------------------------------------------
# The one step a key cannot take
# ---------------------------------------------------------------------------


def report_missing_group(identifiers: list[str], resources: dict[str, str]) -> None:
    """The only hand-work left in signing this app, reduced to two clicks per App ID.

    Two different things produce the same empty group list, and the API can tell them apart from
    neither side: `/v1/appGroups` is a 404, and the APP_GROUPS capability reports `settings: null`
    whether or not a group is assigned to it. Issuing a profile and reading its entitlements, which
    is what got us here, is the only oracle. So this prints both causes in the order they have to be
    fixed, and the App IDs it names are the ones whose freshly issued profile came back empty, not a
    guess: if the group already exists, step 1 is a no-op and the tick in step 2 is the whole job.

    Each line carries the direct URL, because the alternative is a human scrolling a list of
    seventeen identifiers looking for the right one, which is where the wrong one gets edited.
    """
    warn("the profiles cannot sign this app yet.\n")
    print(f"  Release needs {APP_GROUP}, and the App Store Connect API has no endpoint that")
    print("  can create or assign an app group. Signed in as the account holder, once:\n")
    print(f"  1. If {APP_GROUP} does not exist yet, register it:")
    print("     https://developer.apple.com/account/resources/identifiers/add/applicationGroup")
    print(f"       Description: Dawnbreak Shared State    Identifier: {APP_GROUP}")
    print("       The field prefills \"group.\", so type only the rest of it.\n")
    print("  2. Tick it under App Groups → Configure on each of these, and Save:")
    for identifier in identifiers:
        print(f"       {identifier}")
        print(f"         https://developer.apple.com/account/resources/identifiers/bundleId/edit/{resources[identifier]}")
    print("\n     Saving warns that existing profiles are invalidated. That is the point: this")
    print("     script deletes the empty ones and issues them again on the next run.")


def main() -> int:
    client = Client()
    say(f"Provisioning through the App Store Connect API (key {client.key_id})")

    print(f"\n{BOLD}App IDs{RESET}")
    resources = {}
    for name, identifier, _ in TARGETS:
        resources[identifier] = app_identifier(client, name, identifier)
        app_groups_capability(client, resources[identifier])

    print(f"\n{BOLD}Certificates{RESET}")
    certificate_ids, fingerprints, certificate_name = certificates(client)

    print(f"\n{BOLD}Profiles{RESET}")
    missing_group = []
    broken = False
    for _, identifier, profile_name in TARGETS:
        plist, wrong = profile(client, profile_name, resources[identifier],
                               certificate_ids, fingerprints)
        detail = f"{plist['UUID']}, to {plist['ExpirationDate'].date()}"
        if not wrong:
            good(profile_name, f"{detail}, {len(signers(plist))} signing certificate(s)")
            continue
        bad(f"{profile_name}: installed, but {' and '.join(wrong)} ({detail})")
        broken = True
        if any("app group" in reason for reason in wrong):
            missing_group.append(identifier)

    print()
    if missing_group:
        report_missing_group(missing_group, resources)
        return 1
    if broken:
        warn("the profiles cannot sign this app yet, see above.")
        return 1

    say(f"Ready to archive: {certificate_name} ({len(certificate_ids)} certificate(s)), "
        f"{len(TARGETS)} profiles installed")
    print(f"  Signing identity and profile names match project.yml and Configuration/ExportOptions.plist.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
