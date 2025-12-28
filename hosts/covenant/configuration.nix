{ lib, config, pkgs, inputs, ... }:

{
  environment.darwinConfig = inputs.self + /hosts/covenant/configuration.nix;

  # environment.defaultPackages = lib.attrValues { inherit (pkgs) neovim; };
  # environment.variables.EDITOR = "${lib.getExe pkgs.neovim}";
  # environment.variables.PAGER = "${lib.getExe pkgs.less} -RF";

  # environment.shells = [ pkgs.fish ];

  # environment.systemPackages = lib.attrValues {
  #   inherit (pkgs) iterm2 ghostty;
  # };

  # home-manager.users = {
  #   inherit (inputs.self.hmModules) mike;
  # };

  networking.hostName = "covenant";
  networking.computerName = "Covenant";

  # security.pam.enableSudoTouchIdAuth = true;

  system.primaryUser = "mike";

  system.defaults.NSGlobalDomain = {
    AppleKeyboardUIMode = 3; # Enable tabbing through UI elements.
    AppleShowAllExtensions = true;
    AppleInterfaceStyle = "Dark";
    # AppleAquaColorVariant = 1;
    ApplePressAndHoldEnabled = false;
    # AppleMiniaturizeOnDoubleClick = 0;
    AppleWindowTabbingMode = "always";
    "com.apple.trackpad.forceClick" = false;
  };

  system.defaults.WindowManager = {
    EnableStandardClickToShowDesktop = false;
    EnableTiledWindowMargins = false;
  };

  system.defaults.controlcenter = {
    BatteryShowPercentage = true;
  };

  system.defaults.dock = {
    autohide = true;
    mineffect = "scale";
  };

  system.defaults.finder = {
    FXPreferredViewStyle = "Nlsv";
    NewWindowTarget = "Home";
    ShowHardDrivesOnDesktop = true;
    ShowMountedServersOnDesktop = true;
    #ShowPathBar = true;
    ShowStatusBar = true;
  };

  system.defaults.loginwindow = {
    GuestEnabled = false;
  };

  system.defaults.trackpad = {
    Clicking = true;
  };

  homebrew.enable = true;
  homebrew.casks = [
    "1password"
    "adobe-acrobat-reader"
    "alfred"
    "amethyst"
    "antigravity"
    "arc"
    "arduino-ide"
    "brave-browser"
    "caffeine"
    "cursor"
    "discord"
    "docker-desktop"
    "emacs-app"
    "firefox"
    "font-fira-code-nerd-font"
    "font-iosevka"
    "font-iosevka-nerd-font"
    "ghostty"
    "google-chrome"
    "iterm2"
    "lm-studio"
    "localsend"
    "logseq"
    "ngrok"
    "nikitabobko/tap/aerospace"
    "notion"
    "prismlauncher"
    "rectangle"
    "shortcat"
    "spotify"
    "sublime-text"
    "via"
    "vial"
    "visual-studio-code"
    "vlc"
    "windsurf"
    "wireshark-app"
    "zoom"
  ];

  homebrew.onActivation.autoUpdate = true;
  homebrew.onActivation.upgrade = true;

  programs.fish.enable = true;

  users.users.mike = {
    description = "Michael Kaylan";
    shell = pkgs.fish;
    home = "/Users/mike";
  };

  users.users.root.shell = pkgs.fish;

  system.stateVersion = 5;
}
