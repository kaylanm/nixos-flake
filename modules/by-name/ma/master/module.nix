{ pkgs, inputs, ... }:

{
  _module.args.pkgsMaster = import inputs.nixpkgs-master {
    inherit (pkgs.stdenv.hostPlatform) system;
    inherit (pkgs) config;
  };
}
