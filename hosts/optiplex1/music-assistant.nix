{ config, pkgs, ... }:

{
  services.music-assistant = {
    enable = true;
    package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.music-assistant;
    providers = [
      "airplay"
      "apple_music"
      "builtin"
      "chromecast"
      "dlna"
      "filesystem_local"
      "filesystem_smb"
      "fully_kiosk"
      "hass"
      "hass_players"
      "opensubsonic"
      "player_group"
      "radiobrowser"
      "slimproto"
      "snapcast"
      "soundcloud"
      "spotify"
      "ytmusic"
    ];
  };
}
