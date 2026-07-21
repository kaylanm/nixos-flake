{ pkgs, inputs, ... }:

{
  services.matter-server = {
    enable = true;
    package =
      inputs.nixpkgs-matter-server.legacyPackages.${pkgs.stdenv.hostPlatform.system}.python-matter-server;
  };
}
