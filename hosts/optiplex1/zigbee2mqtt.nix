{ config, pkgs, pkgsUnstable, inputs, ... }:

{
  services.zigbee2mqtt = {
    enable = true;
    package = pkgsUnstable.zigbee2mqtt_2;
    settings = {
      advanced = {
        homeassistant_legacy_entity_attributes = false;
        homeassistant_legacy_triggers = false;
        legacy_api = false;
        legacy_availability_payload = false;
      };
      device_options = {
        legacy = false;
      };
      homeassistant = {
        enabled = true;
        experimental_event_entities = true;
      };
      availability = {
        enabled = true;
      };
      serial = {
        port = "/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_6a21b96f1fe8ec118b107a60e89bdf6f-if00-port0";
        adapter = "zstack";
      };
      mqtt = {
        user = "DVES_USER";
        password = "!/etc/zigbee2mqtt/secret.yaml password";
      };
      frontend = {
        enabled = true;
        url = "https://z2m.manx-in.ts.net";
      };
    };
  };

  services.caddy.virtualHosts."https://z2m.manx-in.ts.net".extraConfig = ''
    bind tailscale/z2m

    reverse_proxy :8080
  '';
}
