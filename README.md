# nixos-flake

These are my NixOS, nix-darwin, and home-manager configs. Everything is flake-based,
so I can have my servers update automatically.  Secrets are kept in [sops-nix][sops-nix].

The flake follows the Dendritic Nix pattern with [flake-parts][flake-parts]. The root
`flake.nix` is only the input manifest and entrypoint; cross-cutting concerns live under
`modules/flake/` as flake-parts modules, and reusable system modules are published as named
`flake.modules.<class>.<aspect>` values from the `modules/by-name/` tree.

The reusable module directory organization is inspired by [RFC-0140][rfc-0140].

This repository is inspired by [nixos-configs][nixos-configs].

[home-manager]: https://github.com/nix-community/home-manager
[flake-parts]: https://flake.parts/
[rfc-0140]: https://github.com/NixOS/rfcs/pull/140
[sops-nix]: https://github.com/Mic92/sops-nix
[nixos-configs]: https://github.com/reckenrode/nixos-configs
