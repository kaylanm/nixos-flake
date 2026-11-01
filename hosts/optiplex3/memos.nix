{ config, pkgs, ... }:

{
  virtualisation.oci-containers = {
    containers = {
      memos = {
        image = "docker.io/neosmemo/memos:26.11.0@sha256:087e7dc6b76b31fcd1107a5767398b2a310ced209adb791efd8760c745dc8034";
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
