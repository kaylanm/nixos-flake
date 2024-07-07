{ config, pkgs, ... }:

{
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

