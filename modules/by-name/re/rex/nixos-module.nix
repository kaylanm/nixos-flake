{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  package = inputs.rex.packages.${pkgs.stdenv.hostPlatform.system}.rex;
in
{
  imports = [ inputs.rex.nixosModules.default ];

  options.programs.rex.enable = lib.mkEnableOption "the Rex client";

  config = lib.mkMerge [
    (lib.mkIf config.services.rex.enable {
      # Keep sessions under the usual login account, with access limited to it.
      # Hosts can override these defaults through the upstream service options.
      services.rex = {
        user = lib.mkDefault "mike";
        socketMode = lib.mkDefault "0600";
      };
    })

    (lib.mkIf config.programs.rex.enable {
      environment.systemPackages = [ package ];
      environment.pathsToLink = [ "/share/terminfo" ];
      programs.ssh.extraConfig = lib.mkAfter ''
        Include ${package}/share/rex/ssh_config.d/50-rex.conf
      '';
    })
  ];
}
