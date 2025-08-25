{ config, pkgs, ... }:

{
  systemd.services.minecraft-server-monifactory = {
    #wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "Monifactory Server";
    serviceConfig = {
      Type = "simple";
      User = "minecraft";
      ExecStart = "/var/lib/minecraft-servers/monifactory/run.sh";
      WorkingDirectory = "/var/lib/minecraft-servers/monifactory";
    };
    path = [ pkgs.jdk17 pkgs.bash ];
  };
}
