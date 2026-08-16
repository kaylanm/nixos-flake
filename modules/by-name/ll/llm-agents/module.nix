{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.llm-agents;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  options.programs.llm-agents.enable = lib.mkEnableOption "LLM agent harnesses and tools";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with inputs.llm-agents.packages.${system}; [
      claude-code
      codex
      herdr
      omp
      opencode
      pi
    ];
  };
}
