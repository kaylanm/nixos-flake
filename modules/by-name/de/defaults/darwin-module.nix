{
  flake.modules.darwin.defaults = {
    # Use Determinate Nix on Darwin
    nix.enable = false;

    nixpkgs.config.allowUnfree = true;
  };
}
