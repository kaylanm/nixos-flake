{ config, pkgs, ... }:

{
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        acl = [ "pattern readwrite #" ];
        users = {
          DVES_USER = {
            hashedPasswordFile = "/etc/mosquitto/passwd";
          };
        };
      }
    ];
  };

  environment.systemPackages = [ pkgs.mosquitto ];
}
