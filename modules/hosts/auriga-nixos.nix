{
  config,
  inputs,
  ...
}:

let
  inherit (inputs) nixpkgs-unstable;
  inherit (import ./lib.nix { inherit config inputs; }) mkNixos;
in
{
  flake.nixosConfigurations.auriga-nixos = mkNixos {
    host = "auriga-nixos";
    nixpkgsInput = nixpkgs-unstable;
    # extraModules = [ inputs.home-manager.nixosModules.home-manager ];
  };
}
