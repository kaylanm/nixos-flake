{ config, pkgs, ... }:

{
  services.printing = {
    enable = true;
    drivers = with pkgs; [ brlaser ];
    browsing = true;
    defaultShared = true;
    listenAddresses = [ "*:631" ];
    allowFrom = [ "all" ];
    openFirewall = true;
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    settings.publish = {
      disable-publishing = false;
      disable-user-service-publishing = false;
      publish-addresses = true;
      publish-domain = true;
      publish-workstation = true;
    };
  };

  hardware.printers = {
    ensurePrinters = [
      {
        name = "Brother_MFC-7460DN";
        location = "Home";
        deviceUri = "http://BRN001BA9AC6D3D.home:631";
        model = "drv:///brlaser.drv/br7460d.ppd";
        ppdOptions = {
          media = "na_letter_8.5x11in";
          sides = "one-sided";
          job-sheets = "none, none";
        };
      }
    ];
    ensureDefaultPrinter = "Brother_MFC-7460DN";
  };
}
