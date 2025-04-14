{ config, pkgs, ... }:

{
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        acl = [ "pattern readwrite #" ];
        omitPasswordAuth = true;
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
