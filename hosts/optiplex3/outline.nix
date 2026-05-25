{ pkgs, ... }:

{
  services.outline = {
    enable = true;
    port = 3001;
    publicUrl = "https://outline.manx-in.ts.net/";
    storage.storageType = "local";
  };
}

