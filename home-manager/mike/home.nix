{ lib, pkgs, inputs, withGUI, userName, homeDirectory, userFullName, userEmail, ... }:

{
  home = {
    username = userName;
    homeDirectory = userHomeDirectory;
    stateVersion = "24.11";
  };

  home.packages = [

  ];

  home.sessionVariables = {};

  home.shellAliases = {
    g = "git";
    bg = "batgrep";
    z = "zoxide";
  };

  programs.home-manager.enable = true;

  programs.bat = {
    enable = true;
    extraPackages = with pkgs.bat-extras; [
      batgrep
      batman
    ];
  };

  programs.btop = {
    enable = true;
  };

  programs.eza = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.fish = {
    enable = true;
    shellInit = ''
      set fish_greeting ""
    '';
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.ghostty = {
    enable = withGUI;
  };

  programs.git = {
    enable = true;
    userEmail = userEmail;
    userName = userFullName;

    aliases = {
      co = "checkout";
      cl = "clone";
      s = "status";
      ca = "commit --amend --verbose";
      a = "add --all";
      c = "commit --verbose";
      cb = "checkout -b";
      rb = "rebase --autostash --autosquash --interactive";
      d = "diff";
      ds = "diff --staged";
      pushf = "push --force-with-lease";
      sm = "submodule update --init --recursive";
    };

    lfs.enable = true;

    extraConfig = {
      url."git@github.com:".insteadOf = "https://github.com/";
      push.autoSetupRemote = true;
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimDiffAlias = true;
    plugins = with pkgs.vimPlugins [
      nvim-lspconfig
      nvim-treesitter.withAllGrammars
      plenary-nvim
      gruvbox-material
      mini-nvim
    ];
  };

  programs.rofi = {
    enable = withGUI;
  };

  programs.tmux = {
    enable = true;
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
