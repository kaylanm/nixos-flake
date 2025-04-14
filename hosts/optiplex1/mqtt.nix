{ config, pkgs, ... }:

{
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        acl = [ "pattern readwrite #" ];
        users = {
          DVES_USER = {
            password = "DVES_PASS";
          };
        };
      }
    ];
  };
}
