{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    containers = {
      memos = {
        image = "docker.io/neosmemo/memos:0.29.1";
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
