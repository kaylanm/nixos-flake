{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      homeAssistant = {
        environment.TZ = "America/New_York";
        image = "ghcr.io/home-assistant/home-assistant:2024.7.1";
        extraOptions = [
          "--network=host"
        ];
        volumes = [
          "/var/lib/home-assistant:/config"
        ];
      };
    };
  };
}
