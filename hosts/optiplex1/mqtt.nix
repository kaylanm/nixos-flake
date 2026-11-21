{ config, pkgs, ... }:

{
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        acl = [ "pattern readwrite #" ];
        users = {
          DVES_USER = {
            hashedPasswordFile = config.sops.secrets."mosquitto-password-hash".path;
          };
        };
      }
    ];
  };

  environment.systemPackages = [ pkgs.mosquitto ];
}
