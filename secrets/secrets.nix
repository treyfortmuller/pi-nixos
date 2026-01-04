# This nix file is not imported into the NixOS configuration, its only used for the agenix CLI.

let
  trey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInEEPabEq8zCKUC/3drJTOl3R6s130H4fbskRL2tkgK tfortmuller@mac.com";
in
{
  # OpenWeather API key
  "openweather.age".publicKeys = [
    # Public keys for which the corresponding private key should be able to decrypt the agefile.
    trey
  ];

  # Personal tailscale network auth key, expires April 4, 2026
  "tailscale-authkey.age".publicKeys = [
    trey
  ];
}
