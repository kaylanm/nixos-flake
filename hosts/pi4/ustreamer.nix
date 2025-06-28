{ config, lib, pkgs, inputs, ... }:

{
  services.ustreamer = {
    enable = true;
    extraArgs = [
      "--encoder=HW"
      "--persistent"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 8080 ];
}

