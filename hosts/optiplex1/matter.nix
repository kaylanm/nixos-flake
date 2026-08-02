{ pkgs, inputs, ... }:

{
  services.matterjs-server = {
    enable = true;

    extraArgs = [
      "--vendorid=4939" # 0x143b
      "--fabricid=1"
    ];
  };

  services.tailscale.serve.services.matter.endpoints."tcp:443" = "http://localhost:5580";
}
