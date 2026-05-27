{ inputs, ... }:

let
  modules = import ../top-level/all-modules.nix { inherit (inputs.nixpkgs) lib; };
in
{
  flake.modules = {
    darwin = modules.darwin;
    homeManager = modules.home;
    nixos = modules.nixos;
  };
}
