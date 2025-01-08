{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers = {
    bedrock-server = {
      environment = {
        ALLOW_CHEATS = "false";
        EULA = "true";
        DIFFICULTY = "1";
        SERVER_NAME = "Ryan Minecraft";
        TZ = "US/Eastern";
        VERSION = "LATEST";
        ALLOW_LIST_USERS = "ExInfernum:2533274799590022,Zavazone:2535423916767720";
      };
      image = "itzg/minecraft-bedrock-server:2024.11.0";
      ports = [ "0.0.0.0:19132:19132/udp" ];
      volumes = [ "/var/lib/bedrock-server:/data" ];
    };
  };

  networking.firewall.allowedUDPPorts = [ 19132 ];
}
