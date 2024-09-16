{
  lib,
  pkgs,
  ...
}:

{
  home = {
    username = "mike";
    homeDirectory = "/Users/mike";
    stateVersion = 24.05;
  };

  home.packages = with pkgs; [
    btop
    ripgrep
    fd
    bat
  ];

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  programs.fish.enable = true;

  programs.git = {
    enable = true;
    userEmail = "";
    userName = "";
  };

  programs.neovim.enable = true;

  programs.vscode.enable = true;

  xdg.enable = true;
  xsd.userDirs.enable = true;
}