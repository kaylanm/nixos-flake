{ config, pkgs, inputs, ... }:

{
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      musicAssistant = {
        image = "ghcr.io/music-assistant/server:2.10.8@sha256:661e88bea76a9e79f38feca791f6c7373376ab60766ee01f56b66418ca243b68";
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
