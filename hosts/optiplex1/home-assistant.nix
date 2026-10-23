{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      homeAssistant = {
        environment.TZ = "America/New_York";
        image = "ghcr.io/home-assistant/home-assistant:2026.10.3@sha256:407b89cd11a8cb67d388d21739a226c74acbbebe1ac59e3b83b11b43ce76b98f";
        extraOptions = [
          "--network=host"
        ];
        volumes = [
          "/var/lib/home-assistant:/config"
          "/var/lib/ssl:/ssl"
        ];
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 443 ];
}
