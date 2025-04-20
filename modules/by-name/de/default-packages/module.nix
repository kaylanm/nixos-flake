{ pkgs, pkgsUnstable, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    vim
    neovim
    curl
    wget
    bat
    ripgrep
    silver-searcher
    fzf
    eza
    fd
    btop
    tmux
    screen
    zip
    unzip
    xz
    p7zip
    zstd
    jq
    yq
    watch
    httpie
    socat
    netcat
    lsof
    nix-output-monitor
    nix-tree
    nixfmt-rfc-style
    ookla-speedtest
    dos2unix
    dust
    lazydocker
    lazygit
    hexyl
    difftastic

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
    ncdu
  ]);
  #++ lib.optionals config.withGUI [
  #  nerdfonts
  #];
}
