{ config, pkgs, ... }:

{
  systemd.services.minecraft-server-oceanblock2 = {
    #wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "Oceanblock 2 Server";
    serviceConfig = {
      Type = "simple";
      User = "minecraft";
      ExecStart = "/var/lib/minecraft-servers/oceanblock2/run.sh";
      WorkingDirectory = "/var/lib/minecraft-servers/oceanblock2";
    };
    path = [ pkgs.jdk21 pkgs.bash ];
  };
}
