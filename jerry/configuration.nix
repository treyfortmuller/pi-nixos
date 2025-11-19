{ config, lib, pkgs, ... }:

{
  imports = [ ];

  networking.hostName = "jerry";

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?
}

