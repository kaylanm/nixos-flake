{ pkgs, pkgsUnstable, ... }:

{
  assertions = [
    {
      assertion = pkgs.path == pkgsUnstable.path;
      message = ''
        The shared Fish module requires the host's base nixpkgs to match
        nixpkgs-unstable so the upstream NixOS Fish module and Fish package
        remain compatible.
      '';
    }
  ];

  programs.fish = {
    enable = true;
    package = pkgsUnstable.fish;
    useBabelfish = true;
  };

  users.users.root.shell = pkgsUnstable.fish;
}
