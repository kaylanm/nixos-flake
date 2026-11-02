#!/usr/bin/env python3
"""Create a Buzz agent key and NIP-OA credential locally; never save the owner key."""
import argparse
import getpass
import hashlib
import json
import os
from pathlib import Path

from bech32 import bech32_decode, bech32_encode, convertbits
from coincurve import PrivateKey

def parse_key(value):
    value = value.strip()
    if value.startswith('nsec1'):
        hrp, words = bech32_decode(value)
        decoded = convertbits(words, 5, 8, False) if words is not None else None
        if hrp != 'nsec' or decoded is None or len(decoded) != 32:
            raise ValueError('Invalid nsec private key')
        raw = bytes(decoded)
    else:
        if len(value) != 64:
            raise ValueError('Expected an nsec or 64-character hexadecimal private key')
        raw = bytes.fromhex(value)
    return PrivateKey(raw)


def credential(owner, agent):
    owner_hex = owner.public_key_xonly.format().hex()
    agent_hex = agent.public_key_xonly.format().hex()
    if owner_hex == agent_hex:
        raise ValueError('Agent and owner must have different keys')
    digest = hashlib.sha256(f'nostr:agent-auth:{agent_hex}:'.encode()).digest()
    signature = owner.sign_schnorr(digest)
    assert owner.public_key_xonly.verify(signature, digest)
    auth = json.dumps(['auth', owner_hex, '', signature.hex()], separators=(',', ':'))
    nsec = bech32_encode('nsec', convertbits(agent.secret, 8, 5))
    return f"BUZZ_PRIVATE_KEY={nsec}\nBUZZ_AUTH_TAG='{auth}'\n", agent_hex


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', required=True, help='Expected owner public key (hex)')
    parser.add_argument('--output', type=Path, default=Path('hermes-secrets.env'))
    args = parser.parse_args()
    if len(args.owner) != 64 or any(c not in '0123456789abcdef' for c in args.owner):
        parser.error('Owner must be a lowercase hexadecimal public key')
    if args.output.exists() or args.output.is_symlink():
        parser.exit(1, 'Output already exists; refusing to replace an agent identity.\n')
    try:
        owner = parse_key(getpass.getpass('Buzz owner private key (hidden; nsec or hex): '))
        if owner.public_key_xonly.format().hex() != args.owner:
            parser.exit(1, 'This key does not match the configured relay owner.\n')
        contents, agent_hex = credential(owner, PrivateKey())
    except ValueError:
        # Some decoding errors include input; never echo private key material.
        parser.exit(1, 'Invalid private key; expected nsec or 64 hexadecimal characters.\n')
    try:
        fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as stream:
            os.fchmod(stream.fileno(), 0o600)
            stream.write(contents)
    except FileExistsError:
        parser.exit(1, 'Output already exists; refusing to replace an agent identity.\n')
    except OSError:
        parser.exit(1, 'Could not write credentials; check the output directory and permissions.\n')
    print(f'Wrote agent credentials: {args.output.resolve()} (mode 0600)')
    print(f'Agent public key: {agent_hex}')
    print('The owner private key was not written to the file.')


if __name__ == '__main__':
    main()
