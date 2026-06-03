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
  flake.nixosConfigurations.auriga = mkNixos {
    host = "auriga";
    nixpkgsInput = nixpkgs-unstable;
    # extraModules = [ inputs.home-manager.nixosModules.home-manager ];
  };
}
