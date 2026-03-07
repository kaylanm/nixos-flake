{ config, pkgs, ... }:

{
  systemd.services.minecraft-server-allthemons = {
    #wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "ATMons 10 Server";
    serviceConfig = {
      Type = "simple";
      User = "minecraft";
      ExecStart = "/var/lib/minecraft-servers/allthemons/startserver.sh";
      WorkingDirectory = "/var/lib/minecraft-servers/allthemons";
      Environment = [
        "ATM10_RESTART=false"
        "ATM10_JAVA=${pkgs.jdk21}/bin/java"
      ];
    };
  };
}
