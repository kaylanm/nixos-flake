{ config, pkgs, ... }:

{
  services.minecraft-server = {
    enable = true;
    eula = true;
    openFirewall = true;
    declarative = true;
    whitelist = {
      ExInfernum = "5626c1e5-8638-44fe-87b4-f3ba40fae2f7";
    };
    serverProperties = {
      #server-port = 43000;
      difficulty = 1; # easy
      gamemode = "survival";
      # max-players = 5;
      motd = "Welcome to RyanCraft";
      white-list = true;
      allow-cheats = true;
    };
    #jvmOpts = "-Xms4092M -Xmx4092M -XX:+UseG1GC -XX:+CMSClassUnloadingEnabled -XX:ParallelGCThreads=2 -XX:MinHeapFreeRatio=5 -XX:MaxHeapFreeRatio=10";
  };

  nixpkgs.config.allowUnfree = true;
}

