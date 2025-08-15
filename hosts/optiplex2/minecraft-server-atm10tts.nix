{ config, pkgs, ... }:

{
  systemd.services.minecraft-server-atm10tts = {
    #wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "ATM 10 TTS Server";
    serviceConfig = {
      Type = "simple";
      User = "minecraft";
      ExecStart = "/var/lib/minecraft-servers/atm10tts/startserver.sh";
      WorkingDirectory = "/var/lib/minecraft-servers/atm10tts";
      Environment = [
        "ATM10_RESTART=false"
        "ATM10_JAVA=${pkgs.jdk21}/bin/java"
      ];
    };
  };
}
