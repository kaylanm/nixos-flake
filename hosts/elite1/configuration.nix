{ config, pkgs, lib, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      #./timekpr.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "elite1"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  #services.displayManager.gdm.enable = true;
  #services.displayManager.gdm.autoSuspend = false;
  #services.desktopManager.gnome.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

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
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    #package = config.boot.kernelPackages.nvidiaPackages.stable;
    # Until nvidia driver fixes Thunderbolt eGPUs (broken on 595.71.05) could also try new_feature.
    #package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    #package = config.boot.kernelPackages.nvidiaPackages.new_feature;
    #package = config.boot.kernelPackages.nvidiaPackages.latest;
    #package = config.boot.kernelPackages.nvidiaPackages.beta;

    # The driver that worked on 25.11.
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "580.142";
      sha256_64bit = "sha256-IJFfzz/+icNVDPk7YKBKKFRTFQ2S4kaOGRGkNiBEdWM=";
      sha256_aarch64 = "sha256-jntr88SpTYR648P1rizQjB/8KleBoa14Ay12vx8XETM=";
      openSha256 = "sha256-v968LbRqy8jB9+yHy9ceP2TDdgyqfDQ6P41NsCoM2AY=";
      settingsSha256 = "sha256-BnrIlj5AvXTfqg/qcBt2OS9bTDDZd3uhf5jqOtTMTQM=";
      persistencedSha256 = "sha256-il403KPFAnDbB+dITnBGljhpsUPjZwmLjGt8iPKuBqw=";
    };
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
    update.auto = {
      enable = true;
      onCalendar = "*:0/2:00"; # Every two hours
    };
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
    supertux
    supertuxkart
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
  services.openssh.settings.X11Forwarding = true;

  system.stateVersion = "23.11";
}
