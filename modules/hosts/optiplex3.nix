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
  flake.nixosConfigurations.optiplex3 = mkNixos {
    host = "optiplex3";
    nixpkgsInput = nixpkgs-unstable;
    # extraModules = [ inputs.sops-nix.nixosModules.sops ];
  };
}
