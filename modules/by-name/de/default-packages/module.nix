{ pkgs, pkgsUnstable, ... }:

{
  environment.systemPackages = with pkgs; [
    bat
    btop
    curl
    delta
    difftastic
    dig
    dos2unix
    dust
    eza
    fd
    file
    fzf
    git
    hexyl
    httpie
    jq
    lazydocker
    lazygit
    lshw
    lsof
    mosh
    neovim
    netcat
    nix-output-monitor
    nix-tree
    nixfmt-rfc-style
    ookla-speedtest
    p7zip
    ripgrep
    screen
    silver-searcher
    socat
    tmux
    unzip
    vim
    watch
    wget
    xz
    yq
    zip
    zstd

    # qmk
    # avrdude
    # flashrom
    # dfu-util
    # dfu-programmer
    # # bootloadhid # not in nixpkgs

    # clojure
    # leiningen
    # babashka
    # bbin
    # neil
    # # obb # marked broken


    # mkcert
    # gh
    # awscli
    # k9s
    # cloudlens
    # kubernetes-helm
    # kubectl
    # kubectx
    # kube-linter
    # eksctl
    # kubeseal
    # # kpt # marked broken
    # kustomize
    # skaffold
    # argocd
    # terraform
    # dive
    # step-cli
    # iperf3
    # hexedit

    # go
    # zig
    # cargo
    # rustc

    # helix
    # zed
    # spotify-player

    # git-crypt
    # # ssh-vault # not in nixpkgs

    # yt-dlp
  ] ++ (with pkgsUnstable; [
    # ncdu # zig-hook marked broken
  ]);

  # fonts.packages = [] ++ lib.optionals config.withGUI [
  #  nerdfonts
  #  ghostty
  #];
}
