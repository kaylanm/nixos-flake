{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    containers = {
      memos = {
        image = "docker.io/neosmemo/memos:26.11.1@sha256:5dcd6e6b973a55b964f2fe2ccdaa33319463ab448a23404ebb5d2acbd19299ba";
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
