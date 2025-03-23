{ lib, config, pkgs, inputs, ... }:

{
  environment.darwinConfig = inputs.self + /hosts/covenant/configuration.nix;

  # environment.defaultPackages = lib.attrValues { inherit (pkgs) neovim; };
  # environment.variables.EDITOR = "${lib.getExe pkgs.neovim}";
  # environment.variables.PAGER = "${lib.getExe pkgs.less} -RF";

  # environment.systemPackages = lib.attrValues {
  #   inherit (pkgs) iterm2 ghostty;
  # };

  # home-manager.users = {
  #   inherit (inputs.self.hmModules) mike;
  # };

  networking.hostName = "covenant";
  
  # security.pam.enableSudoTouchIdAuth = true;
}
