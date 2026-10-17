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
      image = "docker.io/itzg/minecraft-bedrock-server:2026.10.1@sha256:6ff3abf645a88c5aafd88b7cf96d35cdfb1e0977a0c45c465a5b536cb1f1c4f9";
      ports = [ "0.0.0.0:19132:19132/udp" ];
      volumes = [ "/var/lib/bedrock-server:/data" ];
    };
  };

  networking.firewall.allowedUDPPorts = [ 19132 ];
}
