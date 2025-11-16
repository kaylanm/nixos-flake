{ config, pkgs, ... }:

{
  systemd.services.minecraft-server-stoneblock4 = {
    #wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "Stoneblock 4 Server";
    serviceConfig = {
      Type = "simple";
      User = "minecraft";
      ExecStart = "/var/lib/minecraft-servers/stoneblock4/run.sh";
      WorkingDirectory = "/var/lib/minecraft-servers/stoneblock4";
    };
    path = [ pkgs.jdk21 pkgs.bash ];
  };
}
