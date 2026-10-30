{ config, pkgs, inputs, ... }:

{
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      musicAssistant = {
        image = "ghcr.io/music-assistant/server:2.10.9@sha256:4ac0d5844363fbbefd6a61251df09d96cd546e05e01b8c1cc1a28803f0935e07";
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
