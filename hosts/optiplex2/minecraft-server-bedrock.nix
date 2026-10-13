{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers = {
    bedrock-server = {
      environment = {
        ALLOW_CHEATS = "true";
        EULA = "true";
        DIFFICULTY = "1";
        SERVER_NAME = "Ryan Minecraft";
        TZ = "US/Eastern";
        VERSION = "LATEST";
        ALLOW_LIST_USERS =
        "ExInfernum:2533274799590022,Zavazone:2535423916767720,LunarCart175331:2535415429916730,TulinShark:2535464932198448,GreenBeastPug:2535459915268742,Nightowl7134:2535458962919233";
        OPS = "2533274799590022,2535415429916730,2535464932198448,2535459915268742,2535458962919233";
      };
      image = "docker.io/itzg/minecraft-bedrock-server:2026.10.0@sha256:0e0eaf6cabd90f6aff4c31a97f7f01aef780ced92de7a1304acdcd519e99b4f0";
      ports = [ "0.0.0.0:19132:19132/udp" ];
      volumes = [ "/var/lib/bedrock-server:/data" ];
    };
  };

  networking.firewall.allowedUDPPorts = [ 19132 ];
}
