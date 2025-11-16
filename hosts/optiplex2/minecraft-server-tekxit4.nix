{ config, pkgs, ... }:

{
  systemd.services.minecraft-server-tekxit4 = {
    #wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "Tekxit 4 Server";
    serviceConfig = {
      Type = "simple";
      User = "minecraft";
      ExecStart = "/var/lib/minecraft-servers/tekxit4/ServerLinux.sh";
      WorkingDirectory = "/var/lib/minecraft-servers/tekxit4";
    };
    path = [ pkgs.jdk17 pkgs.bash ];
  };
}
