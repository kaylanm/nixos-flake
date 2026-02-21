{ pkgsUnstable, ... }:

{
  programs.fish = {
    enable = true;
    package = pkgsUnstable.fish;
    useBabelfish = true;
  };

  users.users.root.shell = pkgsUnstable.fish;
}
