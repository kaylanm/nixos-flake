{ config, pkgs, ... }:

{
  services.mosquitto = {
    enable = true;
    settings = {
      password_file = "/etc/mosquitto/passwd";
    };
    listeners = [
      {
        acl = [ "pattern readwrite #" ];
        omitPasswordAuth = true;
        users = {
          DVES_USER = {};
        };
      }
    ];
  };

  environment.systemPackages = [ pkgs.mosquitto ];
}
