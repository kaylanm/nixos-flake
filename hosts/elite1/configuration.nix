{ config, pkgs, lib, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./timekpr.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "elite1"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;
  #networking.firewall.enable = false;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.autoSuspend = false;
  services.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Disable iGPU
  boot.blacklistedKernelModules = [
    "i915"
  ];
  boot.kernelParams = [
    "i915.modeset=0"
    "snd_hda_core.gpu_bind=0"
  ];

  # Disable nVidia HDMI audio out
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}=="auto", ATTR{remove}="1"
  '';

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  services.flatpak = {
    enable = true;
    packages = [
      "org.vinegarhq.Sober"
      "org.vinegarhq.Vinegar"
    ];
  };

  programs.dconf = {
    enable = true;
    profiles.user.databases = [{
      settings = with lib.gvariant; {
        "org/gnome/mutter" = {
          check-alive-timeout = mkUint32 60000;
        };
      };
    }];
  };

  programs.hyprland.enable = true;
  programs.localsend.enable = true;
  programs.nix-ld.enable = true;
  programs.steam.enable = true;

  services.udev.packages = with pkgs; [ via vial ];

  environment.systemPackages = with pkgs; [
    firefox
    google-chrome
    kitty
    via
    vial
    alacritty
    ghostty
    prismlauncher
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mike = {
    isNormalUser = true;
    description = "Michael Kaylan";
    extraGroups = [ "networkmanager" "wheel" "dialout" ];
    packages = with pkgs; [
      killall
      pciutils
      usbutils
      wofi
      gparted
      #lrzsz
      (vscode-with-extensions.override {
        vscodeExtensions = with vscode-extensions; [
          vscodevim.vim
          ms-python.python
          dracula-theme.theme-dracula
          betterthantomorrow.calva
          jnoortheen.nix-ide
          arrterian.nix-env-selector
          mkhl.direnv
          rust-lang.rust-analyzer
          serayuzgur.crates
          #dustypomerleau.rust-syntax
        ];
      })
    ];
    shell = pkgs.fish;
  };

  users.users.ryan = {
    isNormalUser = true;
    description = "Ryan Kaylan";
    extraGroups = [ "networkmanager" ];
    packages = with pkgs; [

    ];
    shell = pkgs.fish;
  };

  users.users.alex = {
    isNormalUser = true;
    description = "Alex Kaylan";
    extraGroups = [ "networkmanager" ];
    packages = with pkgs; [
      gcompris
    ];
    shell = pkgs.fish;
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  system.stateVersion = "23.11";
}
