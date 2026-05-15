{ pkgs, ... }:

{
  services.ceph = {
    enable = true;
    global = {
      fsid = "68dcbb1c-fb8a-4340-8c5f-9caff0fcadb3";
      monHost = "192.168.1.15";
      monInitialMembers = "elite2";
    };

    osd = {
      enable = true;
      daemons = [
        "0"
        "1"
      ];
      extraConfig = {
        "osd crush chooseleaf type" = "0";
        "osd pool default min size" = "1";
        "osd pool default size" = "2";
      };
    };

    mon = {
      enable = true;
      daemons = [ "elite2" ];
    };

    mgr = {
      enable = true;
      daemons = [ "elite2" ];
    };

    mds = {
      enable = true;
      daemons = [ "elite2" ];
    };
  };

  environment.systemPackages = with pkgs; [ ceph ];

  users.users.ceph = {
    isSystemUser = true;
    group = "ceph";
  };

  users.groups.ceph = {};
}

