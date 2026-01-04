# Run `tailscale up --ssh` for an initial authentication if auto-auth via tailscale.authKeyFile is disabled.
#
# Services that bind to Tailscale IPs should order using
# systemd.services.<name>.after tailscaled-autoconnect.service.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
  cfg = config.serenity.tailscale;
in
{
  options.serenity.tailscale = {
    enable = mkEnableOption "tailscale";

    authKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        An absolute path to a file containing the auth key, tailscale will be
        automatically started if provided. Deploy this with a secrets management
        scheme like agenix or sops-nix.
      '';
      example = "/foo/bar/baz.key";
    };

    # TODO: add an option for a default taildrop path
    # taildropPath = mkOption { }
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.tailscale
    ];

    environment.shellAliases = {
      # TODO: would be nice to keep shell completions for my alias
      ts = "tailscale";

      # TODO:
      # taildrop = "tailscale file get ${cfg.taildropPath}";
    };

    services.tailscale = {
      enable = true;
      authKeyFile = cfg.authKeyFile;

      # Allows tailscale's UDP port through our firewall.
      openFirewall = true;

      # Enable tailscale SSH access to this host automatically.
      extraUpFlags = [
        "--ssh"
      ];
    };
  };
}
