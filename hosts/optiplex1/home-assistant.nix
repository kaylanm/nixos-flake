{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      homeAssistant = {
        environment.TZ = "America/New_York";
        image = "ghcr.io/home-assistant/home-assistant:2025.4.3";
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
