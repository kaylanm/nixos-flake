{ config, lib, pkgs, pkgsUnstable, inputs, ... }:

{
  services.klipper = {
    enable = true;
    firmwares = {
      mcu = {
        enable = true;
        configFile = ./mcu.cfg;
        serial = "/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0";
        enableKlipperFlash = true;
      };
    };
    configFile = ./printer.cfg;
    logFile = "/var/log/klipper.log";
    user = "klipper";
    group = "klipper";
  };

  users.users.klipper = {
    group = "klipper";
    isSystemUser = true;
    #uid = config.ids.uids.klipper;
  };

  users.groups.klipper = {
    #gid = config.ids.gids.klipper;
  };
}

