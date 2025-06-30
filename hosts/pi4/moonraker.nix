{ config, lib, pkgs, pkgsUnstable, inputs, ... }:

{
  services.moonraker = {
    enable = true;

    settings = {
      authorization = {
        #force_logins = true;
        cors_domains = [
          "pi4"
          "*.home"
          "*.manx-in.ts.net"
        ];
        trusted_clients = [
          "192.168.1.0/24"
          "127.0.0.0/8"
          "::1/128"
          "fe80::/10"
          "100.64.0.0/10" # Tailscale CGNAT
        ];
      };
    };
  };

  users.groups.klipper.members = [ "moonraker" ];
}

