{
  config,
  inputs,
  ...
}:

let
  inherit (import ./lib.nix { inherit config inputs; }) mkNixos;
in
{
  flake.nixosConfigurations.elite2 = mkNixos {
    host = "elite2";
    # extraModules = [ inputs.home-manager.nixosModules.home-manager ];
  };
}
