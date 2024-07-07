{ config, pkgs, ... }:

{
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        users = {
          DVES_USER = {
            password = "DVES_PASS";
          };
        };
      }
    ];
  };
}
