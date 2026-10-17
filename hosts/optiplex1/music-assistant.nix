{ config, pkgs, inputs, ... }:

{
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      musicAssistant = {
        image = "ghcr.io/music-assistant/server:2.10.7@sha256:dce482dc3bf4093735acf217b3bead74a05c46d40922341e775580c6d05394cd";
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
