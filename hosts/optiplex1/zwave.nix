{ config, pkgs, inputs, ... }:

{
  services.zwave-js = {
    enable = true;
    serialPort = "/dev/serial/by-id/usb-Silicon_Labs_CP2102N_USB_to_UART_Bridge_Controller_9e8433102294eb118a4a32703d98b6d1-if00-port0";
    secretsConfigFile = "/etc/zwave-secrets.json";
    package = pkgs.zwave-js-server.overrideAttrs (finalAttrs: previousAttrs: {
      version = "3.8.0";
      src = pkgs.fetchFromGitHub {
        owner = "zwave-js";
        repo = "zwave-js-server";
        rev = finalAttrs.version;
        hash = "sha256-/rMeQ+OZdWpRgYwZQNwNa7A7PoTft70LtF2yoUBeKJ4=";
      };
      npmDepsHash = "sha256-F2wgnJfOHrQYAtVFzu2urey1MPuXdB6+7VWvP9JUHxg=";
      npmDeps = pkgs.fetchNpmDeps {
        inherit (finalAttrs) src;
        name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
        hash = finalAttrs.npmDepsHash;
      };
    });
  };
}
