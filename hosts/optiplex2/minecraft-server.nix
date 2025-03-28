{ config, lib, pkgs, ... }:

{
  services.minecraft-server = {
    enable = true;
    eula = true;
    openFirewall = true;
    declarative = true;
    whitelist = {
      ExInfernum = "5626c1e5-8638-44fe-87b4-f3ba40fae2f7";
      Zavazone = "c07a0560-73a9-4f87-969c-e5ecde090872";
    };
    serverProperties = {
      #server-port = 43000;
      difficulty = 1; # easy
      gamemode = "survival";
      # max-players = 5;
      motd = "Welcome to RyanCraft";
      white-list = true;
      allow-cheats = true;
      enable-rcon = true;
      "rcon.password" = "hunter2";
    };
    #jvmOpts = "-Xms4092M -Xmx4092M -XX:+UseG1GC -XX:+CMSClassUnloadingEnabled -XX:ParallelGCThreads=2 -XX:MinHeapFreeRatio=5 -XX:MaxHeapFreeRatio=10";
  };

  systemd.services.minecraft-server.wantedBy = lib.mkForce [ ];
}

