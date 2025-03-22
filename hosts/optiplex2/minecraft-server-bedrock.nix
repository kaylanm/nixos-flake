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
        "ExInfernum:2533274799590022,Zavazone:2535423916767720,LunarCart175331:2535415429916730,TulinShark:2535464932198448,GreenBeastPug:2535459915268742";
        OPS = "2533274799590022,2535415429916730,2535464932198448,2535459915268742";
      };
      image = "itzg/minecraft-bedrock-server:2024.11.0";
      ports = [ "0.0.0.0:19132:19132/udp" ];
      volumes = [ "/var/lib/bedrock-server:/data" ];
    };
  };

  networking.firewall.allowedUDPPorts = [ 19132 ];
}
