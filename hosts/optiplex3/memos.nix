{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    containers = {
      memos = {
        image = "neosmemo/memos:0.25.2";
        ports = [
          "5230:5230"
        ];
        volumes = [
          "/var/lib/memos:/var/opt/memos"
        ];
      };
    };
  };
}
