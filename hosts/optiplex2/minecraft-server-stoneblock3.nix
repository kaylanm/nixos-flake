{ config, pkgs, ... }:

{
  systemd.services.minecraft-server-stoneblock3 = {
    #wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "Stoneblock 3 Server";
    serviceConfig = {
      Type = "simple";
      User = "minecraft";
      ExecStart = ''/var/lib/minecraft-servers/stoneblock3/run.sh '';
      WorkingDirectory = "/var/lib/minecraft-servers/stoneblock3";
    };
    path = [ pkgs.jdk17 pkgs.sh ];
  };
}
