{ config, pkgs, pkgsUnstable, lib, inputs, ... }:

{
  services.timekpr = {
    enable = true;
    package = pkgsUnstable.timekpr;
    adminUsers = [ "mike" ];
  };
}
