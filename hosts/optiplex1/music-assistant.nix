{ config, pkgs, inputs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      musicAssistant = {
        image = "ghcr.io/music-assistant/server:2.6.2";
        extraOptions = [
          "--network=host"
          # "--cap-add=DAC_READ_SEARCH"
          # "--cap-add=SYS_ADMIN"
          # "--security-opt apparmor:unconfined"
        ];
        volumes = [
          "/var/lib/music-assistant:/data"
        ];
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 3483 8095 8096 8097 ];
}
