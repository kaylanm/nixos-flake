{ config, inputs, ... }:

{
  flake.hmModules = {
    mike = {
      imports = [
        ../../home-manager/mike/home.nix
      ]
      ++ builtins.attrValues config.flake.modules.homeManager;
      specialArgs = { inherit inputs; };
      # _module.args = { inherit inputs; };
    };
  };
}
