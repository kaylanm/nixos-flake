{ config, pkgs, ... }:

{
  systemd.services.minecraft-server-atm10 = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "ATM 10 Server";
    serviceConfig = {
      Type = "simple";
      User = "minecraft";
      ExecStart = ''/var/lib/minecraft-servers/atm10-2.38/startserver.sh '';
      WorkingDirectory = "/var/lib/minecraft-servers/atm10-2.38";
      Environment = [
        "ATM10_RESTART=false"
        "ATM10_JAVA=${pkgs.jdk21}/bin/java"
      ];
    };
  };
}
