#!/usr/bin/env python3
"""Register an existing external Buzz agent for Desktop mentions.

Requires bech32 and coincurve. The owner key is read only from a hidden prompt.
This creates a public kind:30177 policy, not another agent key or process.
"""

import argparse
import base64
import getpass
import hashlib
import json
import time
import uuid
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

from bech32 import bech32_decode, convertbits
from coincurve import PrivateKey, PublicKeyXOnly


def encode(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode()


def digest(event):
    return hashlib.sha256(encode([
        0, event["pubkey"], event["created_at"], event["kind"],
        event["tags"], event["content"],
    ])).digest()


def sign(key, kind, tags, content):
    event = dict(pubkey=key.public_key_xonly.format().hex(),
                 created_at=int(time.time()), kind=kind, tags=tags, content=content)
    event["id"] = digest(event).hex()
    event["sig"] = key.sign_schnorr(bytes.fromhex(event["id"])).hex()
    return event


def verify(event):
    event_digest = digest(event)
    if event["id"] != event_digest.hex() or not PublicKeyXOnly(
        bytes.fromhex(event["pubkey"])
    ).verify(bytes.fromhex(event["sig"]), event_digest):
        raise ValueError("Relay returned an invalid event signature")


def parse_key(value):
    value = value.strip()
    if value.startswith("nsec1"):
        hrp, words = bech32_decode(value)
        raw = convertbits(words, 5, 8, False) if words is not None else None
        if hrp != "nsec" or raw is None or len(raw) != 32:
            raise ValueError("Invalid nsec private key")
        return PrivateKey(bytes(raw))
    if len(value) != 64:
        raise ValueError("Expected an nsec or 64-character hexadecimal private key")
    return PrivateKey(bytes.fromhex(value))


class NoRedirect(HTTPRedirectHandler):
    # Never forward signed authentication to another URL.
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def post(relay, path, value, key):
    url = relay + path
    body = encode(value)
    auth = sign(key, 27235, [
        ["u", url], ["method", "POST"], ["nonce", str(uuid.uuid4())],
        ["payload", hashlib.sha256(body).hexdigest()],
    ], "")
    request = Request(url, data=body, headers={
        "Content-Type": "application/json",
        "Authorization": "Nostr " + base64.b64encode(encode(auth)).decode(),
    })
    with build_opener(NoRedirect).open(request, timeout=30) as response:
        return json.load(response)


def latest(relay, key, author, kind, agent=None):
    query = {"kinds": [kind], "authors": [author], "limit": 1}
    if agent:
        query["#d"] = [agent]
    events = post(relay, "/query", [query], key)
    if not isinstance(events, list):
        raise ValueError("Unexpected relay query response")
    if not events:
        return None
    event = events[0]
    verify(event)
    if event["pubkey"] != author or event["kind"] != kind or (
        agent and ["d", agent] not in event["tags"]
    ):
        raise ValueError("Relay returned an event outside the requested identity")
    return event


def register(relay, key, owner, agent, name):
    if key.public_key_xonly.format().hex() != owner:
        raise ValueError("The private key does not match the configured owner")
    profile = latest(relay, key, agent, 0)
    if not profile:
        raise ValueError("Publish the agent's signed Buzz profile first")
    auth = [tag for tag in profile["tags"] if tag and tag[0] == "auth"]
    if len(auth) != 1 or len(auth[0]) != 4 or auth[0][1] != owner:
        raise ValueError("The agent profile does not attest this owner")
    # This setup uses an unrestricted owner attestation; do not interpret or
    # silently accept conditional attestations with different semantics.
    if auth[0][2] != "" or not key.public_key_xonly.verify(
        bytes.fromhex(auth[0][3]),
        hashlib.sha256(f"nostr:agent-auth:{agent}:".encode()).digest(),
    ):
        raise ValueError("The profile's owner attestation is invalid or conditional")

    policy = {"name": name, "parallelism": 1,
              "respond_to": "owner-only", "respond_to_allowlist": []}
    existing = latest(relay, key, owner, 30177, agent)
    if existing:
        if json.loads(existing["content"]) != policy:
            raise ValueError("An existing owner policy differs; refusing to replace it")
        return "The owner-only policy is already registered."

    event = sign(key, 30177, [["d", agent]], encode(policy).decode())
    result = post(relay, "/events", event, key)
    if isinstance(result, dict) and (result.get("error") or result.get("accepted") is False):
        raise ValueError("Relay rejected the registration")
    stored = latest(relay, key, owner, 30177, agent)
    if not stored or stored["id"] != event["id"]:
        raise ValueError("Registration was submitted but could not be verified; rerun to check")
    return "Registered and verified the owner-only agent policy."


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--relay", default="https://buzz.manx-in.ts.net")
    parser.add_argument("--owner", required=True)
    parser.add_argument("--agent", required=True)
    parser.add_argument("--name", default="Hermes")
    args = parser.parse_args()
    relay = args.relay.rstrip("/")
    url = urlsplit(relay)
    if url.scheme != "https" or not url.hostname or url.username or url.query or url.fragment:
        parser.error("Relay must be an HTTPS URL without credentials, query, or fragment")
    for value in [args.owner, args.agent]:
        if len(value) != 64 or any(c not in "0123456789abcdef" for c in value):
            parser.error("Owner and agent must be lowercase hexadecimal public keys")
    if args.owner == args.agent:
        parser.error("Owner and agent must be separate identities")
    print(f"Register {args.name} ({args.agent}) on {relay}; responses: owner-only.")
    try:
        key = parse_key(getpass.getpass("Buzz owner private key (hidden; nsec or hex): "))
        print(register(relay, key, args.owner, args.agent, args.name))
    except HTTPError as exc:
        parser.exit(1, f"Relay HTTP error {exc.code}; no credentials were saved.\n")
    except (ValueError, KeyError, TypeError, OSError) as exc:
        # Do not print exception details: malformed key errors can contain input.
        if isinstance(exc, ValueError) and str(exc).startswith((
            "The ", "Relay ", "Publish ", "An existing ", "Registration ",
        )):
            parser.exit(1, f"{exc}\n")
        parser.exit(1, "Registration failed; check the key, relay, and connectivity. No credentials were saved.\n")


if __name__ == "__main__":
    main()
