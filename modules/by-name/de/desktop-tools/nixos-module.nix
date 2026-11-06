{ config, lib, pkgs, ... }:

{
  environment.systemPackages = lib.optionals config.services.xserver.enable [
    pkgs.efibootmgr
  ];
}
