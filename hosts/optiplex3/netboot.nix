{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers = {
    netboot = {
      image = "ghcr.io/netbootxyz/netbootxyz:0.7.6-nbxyz23@sha256:39bb40c85d1f6e500b3df1871460f88609215735c224b234b9e6e4e849faf92b";
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
