{ config, pkgs, ... }:

{
  # networking.firewall.allowedTCPPorts = [ 631 ];
  # networking.firewall.allowedUDPPorts = [ 631 ];

  #services.printing = {
    #enable = true;
    #drivers = with pkgs; [ brlaser ];
    #browsing = true;
    #defaultShared = true;
    #listenAddresses = [ "*:631" ];
    #allowFrom = [ "all" ];
  #};

  #services.avahi = {
    #enable = true;
    #nssmdns = true;
    #openFirewall = true;
    #publish = {
      #enable = true;
      #addresses = true;
      #domain = true;
      #userServices = true;
      #workstation = true;
    #};
  #};

  #system.nssModules = pkgs.lib.optional true pkgs.nssmdns;
  #system.nssDatabases.hosts = pkgs.lib.optionals true (pkgs.lib.mkMerge [
    #(pkgs.lib.mkBefore [ "mdns4_minimal [NOTFOUND=return]" ])
    #(pkgs.lib.mkAfter [ "mdns4" ])
  #]);

  #hardware.printers = {
    #ensurePrinters = [
      #{
        #name = "Brother_MFC-7460DN";
        #location = "Home";
        #deviceUri = "dnssd://Brother%20MFC-7460DN._pdl-datastream._tcp.local/";
        #model = "br7460dn.ppd";
        #ppdOptions = {};
      #}
    #];
    #ensureDefaultPrinter = "Brother_MFC-7460DN";
  #};
}