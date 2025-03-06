{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      homeAssistant = {
        environment.TZ = "America/New_York";
        image = "ghcr.io/home-assistant/home-assistant:2025.3.0";
        extraOptions = [
          "--network=host"
          "--device=/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_6a21b96f1fe8ec118b107a60e89bdf6f-if00-port0"
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
