{
  config,
  lib,
  pkgs,
  ...
}:

{
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      homeAssistant = {
        environment.TZ = "America/New_York";
        image = "ghcr.io/home-assistant/home-assistant:2026.11.1@sha256:6785d1eca68747a524c156faae1b139ed415c07357386ae6fe17291986e59e82";
        extraOptions = [
          "--network=host"
        ];
        volumes = [
          "/var/lib/home-assistant:/config"
          "${pkgs.alarmo}:/config/custom_components/alarmo:ro"
          "/var/lib/ssl:/ssl"
        ];
      };
    };
  };

  # Refuse to mask an unmanaged installation with the read-only component mount.
  systemd.services.podman-homeAssistant = {
    path = [
      pkgs.coreutils
      pkgs.findutils
    ];
    preStart = lib.mkBefore ''
      ${pkgs.bash}/bin/bash ${./home-assistant/prepare-alarmo.sh} /var/lib/home-assistant
    '';
  };

  networking.firewall.allowedTCPPorts = [ 443 ];
}
