{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ];

  networking.hostName = "jerry";

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?

  age = {
    identityPaths = [
      # This path is set up imperatively, bootstrapping trust is always left as an exercise for the developer
      "/home/pi/.ssh/id_ed25519"
    ];
    secrets.openweather =
      let
        wf = config.serenity.services.weatherframe;
      in
      {
        file = ../secrets/openweather.age;

        # Make sure whatever user/group is running the weatherframe service can read the decrypted file
        owner = wf.user;
        group = wf.group;
        mode = "400"; # Owner readable, and nothing else
      };
    secrets.tailscale = {
      file = ../secrets/tailscale-authkey.age;
    };
  };

  serenity = {
    localDev = {
      enable = true;
      enableVSCodeServer = true;
    };
    services.weatherframe = {
      enable = true;
      weatherLat = 33.617;
      weatherLon = -117.831;
      apiKeyPath = config.age.secrets.openweather.path;
    };
    tailscale = {
      enable = true;
      authKeyFile = config.age.secrets.tailscale.path;
    };
  };

  environment.systemPackages = [
    pkgs.openwx
    pkgs.tatted # binary is called tatctl
  ];
}
