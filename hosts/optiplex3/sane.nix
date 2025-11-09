{ config, pkgs, pkgsUnstable, ... }:

{
  hardware.sane = {
    enable = true;

    brscan4 = {
      enable = true;

      netDevices = {
        mfc7460dn = {
          model = "MFC-7460DN";
          name = "MFC-7460DN";
          nodename = "BRN001BA9AC6D3D";
        };
      };
    };
  };

  services.avahi = {
    enable = true;
  };

  #services.saned = {
  #  enable = true;
  #  extraConfig = "192.168.1.0/24";
  #};
}

