{
  flake.modules.darwin.default-packages =
    { pkgs, inputs, ... }:
    {
      environment.systemPackages = with pkgs; [

      ];
    };
}
