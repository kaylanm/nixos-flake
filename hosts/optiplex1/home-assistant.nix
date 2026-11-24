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
        image = "ghcr.io/home-assistant/home-assistant:2026.11.3@sha256:24e541ddae5818bf8eb27898b9ba00d0c344a655aa5097e9e9bd4b19356be847";
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
