{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nix.gc = {
    automatic = true;
    interval = {
      Weekday = 0;
      Hour = 0;
      Minute = 0;
    };
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;
}
