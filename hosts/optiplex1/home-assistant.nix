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
        image = "ghcr.io/home-assistant/home-assistant:2026.11.2@sha256:493a07e8f6530fc640223f4a0a5248f20a61ca2f718bb1d31efbf08a2c5ea28f";
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
