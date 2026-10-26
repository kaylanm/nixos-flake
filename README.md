# nixos-flake

These are my NixOS, nix-darwin, and home-manager configs. Everything is flake-based, 
so I can have my servers update automatically.  Secrets are kept in [sops-nix][sops-nix].

The current version of this flake favors explicit configuration and uses modules to share common
configuration settings.  The modules directory organization is inspired by [RFC-0140][rfc-0140].

This repository is inspired by [nixos-configs][nixos-configs].

Renovate also tracks opt-in, literal `fetchFromGitHub` commit pins. Put
`# renovate: ref=main` immediately before `rev` in a block containing `owner`,
`repo`, `rev`, and `hash`, in that order. Change `main` to the desired upstream
branch. The hosted Renovate app updates the commit; the
`Refresh fetchFromGitHub hashes` workflow refreshes the archive hash on its PR
and dispatches the system build workflow for the resulting commit. The refresh
job requires repository `contents: write` and `actions: write` permissions.
Fetches with options such as `fetchSubmodules`, `fetchLFS`, or `postFetch` need
their own update strategy; leave them unannotated.

To refresh annotated hashes locally, run
`python3 .github/scripts/update-fetchgithub-hashes.py`. This updates hashes for
the existing pinned commits; it does not advance revisions itself.

[home-manager]: https://github.com/nix-community/home-manager
[rfc-0140]: https://github.com/NixOS/rfcs/pull/140
[sops-nix]: https://github.com/Mic92/sops-nix
[nixos-configs]: https://github.com/reckenrode/nixos-configs
