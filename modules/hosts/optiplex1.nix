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
  flake.nixosConfigurations.optiplex1 = mkNixos {
    host = "optiplex1";
    nixpkgsInput = nixpkgs-unstable;
    # extraModules = [ inputs.sops-nix.nixosModules.sops ];
  };
}
