{ config, inputs, ... }:

{
  flake.colmena = {
    meta = {
      nixpkgs = import inputs.nixpkgs {
        system = "x86_64-linux";
        overlays = [ ];
      };
    };
  }
  // builtins.mapAttrs (_: value: {
    imports = value._module.args.modules;
  }) config.flake.nixosConfigurations;
}
