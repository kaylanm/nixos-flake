{ config, pkgs, ... }:

{
  # The SNMP driver needs the network before it can detect the UPS.
  systemd.services.upsdrv = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  power.ups = {
    enable = true;
    mode = "netserver";
    openFirewall = true;
    ups.apc = {
      driver = "snmp-ups";
      port = "192.168.1.216";
    };
    users = {
      nutuser = {
        passwordFile = "/etc/nut-passwd";
        instcmds = [ "ALL" ];
      };
    };
    upsmon = {
      monitor = {
        apc = {
          system = "apc@localhost";
          user = "nutuser";
          passwordFile = "/etc/nut-passwd";
        };
      };
    };
  };
}

