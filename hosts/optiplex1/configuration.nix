# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "optiplex1"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Remove this after https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.NetworkManager-wait-online.enable = pkgs.lib.mkForce false;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  #services.home-assistant = {
    #enable = true;
    #extraComponents = [
      #"esphome"
      #"met"
      #"radio_browser"
      #"tplink"
      #"awair"
    #];
    #config = {
      #default_config = {};
    #};
  #};

  programs.fish.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mike = {
    isNormalUser = true;
    description = "Michael Kaylan";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ neovim vim ];
    shell = pkgs.fish;
  };

  users.users.root = {
    shell = pkgs.fish;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
     git
     vim
     neovim
     wget
     curl
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  #networking.firewall.allowedTCPPorts = [ 8123 ];


  networking.firewall.allowedTCPPorts = [ 631 8123 ];
  networking.firewall.allowedUDPPorts = [ 631 ];

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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

}
