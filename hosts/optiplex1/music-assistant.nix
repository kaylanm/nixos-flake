{ config, pkgs, inputs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      musicAssistant = {
        image = "ghcr.io/music-assistant/server:2.9.10";
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

  services.tailscale.serve.services.musicassistant.endpoints."tcp:443" = "http://localhost:8095";

  networking.firewall.allowedTCPPorts = [ 3483 8095 8096 8097 ];
}
