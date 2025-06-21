{ config, lib, pkgs, inputs, ... }:

{
  services.ustreamer = {
    enable = true;
    extraArgs = [
      "--encoder=HW"
      "--persistent"
      "--drop-same-frames=30"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 8080 ];
}

