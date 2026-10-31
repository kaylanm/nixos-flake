{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    containers = {
      memos = {
        image = "docker.io/neosmemo/memos:26.10.0@sha256:fbc6ef8e9e0b377377f0d71d426d6192a9a0f08a8e3e35bec3557a43f4399260";
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
