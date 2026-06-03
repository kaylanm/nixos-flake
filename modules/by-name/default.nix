{
  imports = [
    ./br/brscan-skey/nixos-module.nix
    ./de/default-packages/darwin-module.nix
    ./de/default-packages/module.nix
    ./de/default-packages/nixos-module.nix
    ./de/defaults/darwin-module.nix
    ./de/defaults/module.nix
    ./de/defaults/nixos-module.nix
    ./fi/fish/nixos-module.nix
    ./ma/master/module.nix
    ./mo/mosh/nixos-module.nix
    ./ne/neovim/nixos-module.nix
    ./pk/pkgs-overlay/module.nix
    ./un/unstable/module.nix
  ];

  flake.modules.homeManager = { };
}
