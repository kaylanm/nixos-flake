# Prototype security review and execution evidence

## Independent review

A separate Hermes process independently inspected the Python, Nix and README,
installed Hermes auth/provider/WS code, and Uvicorn protocol upgrade paths.
Review session: `local-e30fee0f4ff5c209a68071299c6f8aee62e39816658203e6272c86aaafea3c1b`.
Its final structured verdict was `passed: true`, `security_concerns: []`,
`logic_errors: []`. It independently ran the complete discovery-based suite:
**21 tests passed**, exit 0, and parsed the Nix expression. This is a code review
by an independent agent context, not a professional audit or deployment approval.

An earlier independent pass identified inherited ContextVar lifetime and uncaught
malformed WS query decoding. Both received failing regression tests, fixes and
successful re-review. The mutable shared lease revokes inherited child contexts;
the verifier checks expiry; malformed query decoding returns a controlled denial.
A real package-build failure also exposed a socket umask held across the server
lifetime and ambient HTTP CA settings; both were corrected and regression tested.

Nonblocking review suggestions: exercise exception/cancellation lease cleanup,
explicit mismatched-UID WS denial, and bound all test startup polling loops.
The direct-test `unittest.main()` placement suggestion was addressed after review.
Ruff import/format/style cleanup followed; the full tests are rerun by the build.

## Verified execution scope

- Complete prototype suite against installed Hermes 0.22.5: 21 passing tests.
- Standalone Nix derivation runs the same suite before installing artifacts.
- Installed package CLI `--help` and its `test` subcommand exercised.
- Real HTTP identity/sessions/streamed export; real gateway WS 101 plus initial
  JSON frame; real WS broadcast, allowed and denied handshakes.
- Missing/disallowed/duplicate identity, Host/Origin/CSRF rejection, alternate
  credentials, valid ticket non-bypass, request principal isolation, inherited
  context invalidation, malformed query, kernel peer mismatch and TCP spoofing.
- Ruff check and formatting check; staged whitespace and added-line static scan.

Not verified: real Tailscale Serve header insertion/stripping, tailscaled's root
peer, actual iOS applications, Fleet pairing, full browser/dashboard startup,
normal runtime background jobs, arbitrary plugin/token-route behavior, production
cutover. Nothing here enables the prototype in the flake or changes live auth.

The standalone Codex CLI review attempt failed with HTTP 401; no verdict from
that attempt was used. The independent Hermes review above completed successfully.
