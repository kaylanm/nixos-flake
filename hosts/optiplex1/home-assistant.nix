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
        image = "ghcr.io/home-assistant/home-assistant:2026.11.0@sha256:c6c1ca9931036bf3a2c4cc088d8db25dfea3b33935a5ecc83c40349462e2f69e";
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
