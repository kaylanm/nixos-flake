{ config, pkgs, inputs, ... }:

{
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      musicAssistant = {
        image = "ghcr.io/music-assistant/server:2.10.11@sha256:b14d5c1c93d776f33b9670a3c6febe3f072566d7b2f4f431a09dcca79bd8ac05";
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
