{ config, pkgs, ... }:

{
  systemd.services.minecraft-server-atm9tts = {
    #wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "ATM 9 TTS Server";
    serviceConfig = {
      Type = "simple";
      User = "minecraft";
      ExecStart = "/var/lib/minecraft-servers/atm9tts/startserver.sh";
      WorkingDirectory = "/var/lib/minecraft-servers/atm9tts";
      Environment = [
        "ATM9_RESTART=false"
        "ATM9_JAVA=${pkgs.jdk17}/bin/java"
      ];
    };
  };
}
