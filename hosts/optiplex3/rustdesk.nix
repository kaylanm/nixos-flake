{ pkgs, ... }:

{
  services.rustdesk-server = {
    enable = true;
    openFirewall = true;
    signal = {
      relayHosts = [ "optiplex3.manx-in.ts.net" ];
    };
  };
}

