{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption types;

  cfg = config.serenity.services.weatherframe;

  serviceConfig = {
    coords = {
      lat = cfg.weatherLat;
      lon = cfg.weatherLon;
    };
    units = cfg.weatherUnits;
    api_key_path = cfg.apiKeyPath;
    refresh_interval = {
      secs = cfg.refreshInterval;
      nanos = 0;
    };
    inky = {
      display_res = {
        width = cfg.displayWidth;
        height = cfg.displayHeight;
      };
      spi_path = "/dev/spidev0.0";
      gpios = {
        gpio_chip = "/dev/gpiochip0";
        chip_select = 8;
        data_cmd = 22;
        reset = 27;
        busy = 17;
      };
    };
  };

  serviceConfigJson = builtins.toJSON serviceConfig;
  serviceConfigFile = pkgs.writeText "config.json" (serviceConfigJson);
in
{
  imports = [ ];

  options.serenity.services.weatherframe = {
    enable = mkEnableOption "weatherframe service";

    package = mkOption {
      default = pkgs.weatherframe;
      type = types.package;
      description = "the weatherframe package to use";
    };

    debugLogging = mkEnableOption "debug logging";

    user = mkOption {
      type = types.str;
      default = "pi";
      description = "User under which the weatherframe service is run.";
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = "Group under which the weatherframe service is run.";
    };

    apiKeyPath = mkOption {
      type = types.path;
      description = ''
        Filepath to a file containing the OpenWeather API key, ideally you're using some sort of secrets management
        tool, in the case of agenix it'll look like:

        config.age.secrets.openweather.path
      '';
    };

    displayWidth = mkOption {
      default = 400;
      type = types.ints.positive;
      description = ''
        Width of the inky display in pixels.
      '';
    };

    displayHeight = mkOption {
      default = 300;
      type = types.ints.positive;
      description = ''
        Height of the inky display in pixels.
      '';
    };

    refreshInterval = mkOption {
      default = 1200; # 20 minutes
      type = types.ints.positive;
      description = ''
        The refresh interval, expressed in seconds, between weather polls and display updates, should be greater
        than 10 minutes since thats how frequently OpenWeather updates.
      '';
    };

    weatherUnits = mkOption {
      default = "Imperial";
      type = types.enum [
        "Standard"
        "Imperial"
        "Metric"
      ];
      description = ''
        The units of measure that the weather is fetched with.
      '';
    };

    weatherLat = mkOption {
      default = 33.617;
      type = types.float;
      description = ''
        Latitude of the position to sample for the weather.
      '';
    };

    weatherLon = mkOption {
      default = -117.831;
      type = types.float;
      description = ''
        Longitude of the position to sample for the weather.
      '';
    };

    serviceConfig = mkOption {
      default = serviceConfigJson;
      type = types.str;
      readOnly = true;
      internal = true;
      description = ''
        Read-only inspection of the generated JSON service config file. Ex:

        nix eval .#nixosConfigurations.machine.config.services.myservice.serviceConfig --raw | jq
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # This service uses the inky display, enable it by default!
    serenity.inky.enable = true;

    environment.systemPackages = with pkgs; [
      weatherframe
    ];

    systemd.services.weatherframe = {
      description = "OpenWeather e-ink display dashboard";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "20s";
        ReadOnlyPaths = [
          "${serviceConfigFile}"
          "${cfg.apiKeyPath}"
        ];
        ExecStart =
          "${cfg.package}/bin/weatherframe run --config-path ${serviceConfigFile}"
          + lib.optionalString cfg.debugLogging " --debug";
      };
    };
  };
}
