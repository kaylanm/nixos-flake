{ config, pkgs, pkgsUnstable, lib, inputs, ... }:

{
  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/security/timekpr.nix"
  ];

  services.timekpr = {
    enable = true;
    package = pkgsUnstable.timekpr;
    adminUsers = [ "mike" ];
  };
}
