{ config, pkgs, ... }:

{
  virtualisation.oci-containers.containers = {
    netboot = {
      image = "ghcr.io/netbootxyz/netbootxyz:0.7.6-nbxyz23";
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

  services.tailscale.serve.services.netboot.endpoints."tcp:443" = "http://localhost:3000";
}
