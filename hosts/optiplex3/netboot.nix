{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers = {
    netboot = {
      image = "ghcr.io/netbootxyz/netbootxyz";
      ports = [
        "3000:3000"
        "69:69/udp"
        "8080:80"
      ];
      volumes = [
        "/var/lib/netbootxyz/config:/config"
        "/var/lib/netbootxyz/assets:/assets"
      ];
    };
  };
}

