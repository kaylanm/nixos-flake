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
  flake.nixosConfigurations.optiplex2 = mkNixos {
    host = "optiplex2";
    nixpkgsInput = nixpkgs-unstable;
    # extraModules = [ inputs.sops-nix.nixosModules.sops ];
  };
}
