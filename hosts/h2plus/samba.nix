{ pkgs, ... }:

{
  services.samba = {
    enable = true;
    package = pkgs.samba.override { enableMDNS = true; };
    nmbd.enable = false;
    winbindd.enable = false;

    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server role" = "standalone server";
      };

      data = {
        comment = "Data";
        path = "/tank/data";
        "valid users" = "mike";
        "read only" = "no";
        browseable = "yes";
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:encoding" = "native";
      };

      backups = {
        comment = "Time Machine Backups";
        path = "/tank/backups";
        "valid users" = "@timemachine";
        "read only" = "no";
        browseable = "yes";
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:encoding" = "native";
        "fruit:time machine" = "yes";
        "fruit:time machine max size" = "4T";
      };
    };
  };

  # Samba's Time Machine share registers itself through Avahi when mDNS is
  # enabled in the Samba build.
  services.avahi = {
    enable = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # Do not start serving paths on the root filesystem before ZFS has mounted
  # the datasets from tank.
  systemd.services.samba-smbd = {
    after = [ "zfs.target" ];
    wants = [ "zfs.target" ];
  };

  # Modern SMB uses direct hosting on TCP 445. Avahi opens UDP 5353 for mDNS.
  networking.firewall.allowedTCPPorts = [ 445 ];
}
