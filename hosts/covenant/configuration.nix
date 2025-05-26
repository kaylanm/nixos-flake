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

  homebrew.enable = true;
  homebrew.casks = [
    "1password"
    "adobe-acrobat-reader"
    "aerospace"
    "alfred"
    "amethyst"
    "arc"
    "arduino-ide"
    "brave-browser"
    "caffeine"
    "discord"
    "docker"
    "emacs"
    "firefox"
    "font-fira-code-nerd-font"
    "font-iosevka"
    "font-iosevka-nerd-font"
    "ghostty"
    "google-chrome"
    "iterm2"
    "localsend"
    "logseq"
    "ngrok"
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
    "vmware-fusion"
    "wireshark"
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
