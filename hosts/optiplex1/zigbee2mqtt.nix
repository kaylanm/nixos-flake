{ config, pkgs, inputs, ... }:

{
  services.zigbee2mqtt = {
    enable = true;
    package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.zigbee2mqtt_2;
    settings = {
      homeassistant = true;
      serial = {
        port = "/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_6a21b96f1fe8ec118b107a60e89bdf6f-if00-port0";
        adapter = "zstack";
      };
      mqtt = {
        user = "DVES_USER";
        password = "!/etc/zigbee2mqtt/secret.yaml password";

      };
    };
  };
}
