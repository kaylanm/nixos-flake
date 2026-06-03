{
  flake.modules = {
    darwin.pkgs-overlay = {
      nixpkgs.overlays = [ (import ../../../../overlays/default.nix) ];
    };

    nixos.pkgs-overlay = {
      nixpkgs.overlays = [ (import ../../../../overlays/default.nix) ];
    };
  };
}
