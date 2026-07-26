{ pkgs, inputs, ... }:

{
  services.matterjs-server = {
    enable = true;

    extraArgs = [
      "--vendorid=4939" # 0x143b
      "--fabricid=1"
    ];
  };
}
