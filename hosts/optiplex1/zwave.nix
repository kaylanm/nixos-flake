{ config, pkgs, inputs, ... }:

{
  services.zwave-js = {
    enable = true;
    serialPort = "/dev/serial/by-id/usb-Silicon_Labs_CP2102N_USB_to_UART_Bridge_Controller_9e8433102294eb118a4a32703d98b6d1-if00-port0";
    secretsConfigFile = "/etc/zwave-secrets.json";
    # package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.zwave-js-server;
    # TODO: Remove this when zwave-js-server is updated in nixpkgs-unstable.
    package = pkgs.callPackage (import ./zwave-js-server.nix) {};
  };
}
