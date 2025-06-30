{ config, lib, pkgs, pkgsUnstable, inputs, ... }:

{
  services.mainsail = {
    enable = true;
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}

