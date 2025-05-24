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
    nssmdns = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      userServices = true;
      workstation = true;
    };
  };

  system.nssModules = pkgs.lib.optional true pkgs.nssmdns;
  system.nssDatabases.hosts = pkgs.lib.optionals true (pkgs.lib.mkMerge [
    (pkgs.lib.mkBefore [ "mdns4_minimal [NOTFOUND=return]" ])
    (pkgs.lib.mkAfter [ "mdns4" ])
  ]);

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
