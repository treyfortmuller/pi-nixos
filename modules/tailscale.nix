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

    localTaildropPath = mkEnableOption "" // {
      description = ''
        Enables the creation of a $HOME/taildrop directory for the pi user, and the
        the creation of the taildrop alias to quickly grab files from the taildrop inbox.
      '';
    };

    hostName = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        hostname to use on the tailnet instead of the one provided by the OS.
        Null will use the hostname of the machine.
      '';
    };

    operator = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Unix username to allow to operate on tailscaled without sudo. Null indicates
        that sudo must be used by all users to make changes or use taildrop.
      '';
    };
  };

  config =
    let
      piUser = config.users.users.pi;
      taildropPath = "${piUser.home}/taildrop";
    in
    mkIf cfg.enable {
      environment.systemPackages = [
        pkgs.tailscale
      ];

      systemd.tmpfiles.rules = lib.optionals cfg.localTaildropPath [
        "d ${taildropPath} - ${piUser.name} users - -"
      ];

      environment.shellAliases = {
        ts = "tailscale";
      }
      // lib.optionalAttrs cfg.localTaildropPath {
        taildrop = "tailscale file get ${taildropPath}";
      };

      programs.bash.interactiveShellInit = ''
        complete -F _complete_alias ts
        complete -F _complete_alias taildrop
      '';

      services.tailscale = {
        enable = true;
        authKeyFile = cfg.authKeyFile;

        # Allows tailscale's UDP port through our firewall.
        openFirewall = true;

        # Note this are only relevant to the automatic login provided by the authKeyFile. Be aware
        # that extraUpFlags requires multi-word arguments to be included in the list separately,
        # the args are each passed through lib.escapeShellArgs:
        #
        # nix-repl> lib.escapeShellArgs [ "--ssh" "--hostname foobar" "--operator my-user" ]
        # "--ssh '--hostname foobar' '--operator my-user'"
        extraUpFlags = [
          # Enable tailscale SSH access to this host automatically.
          "--ssh"
        ]
        ++ lib.optionals (!isNull cfg.hostName) [
          "--hostname"
          "${cfg.hostName}"
        ]
        ++ lib.optionals (!isNull cfg.operator) [
          "--operator"
          "${cfg.operator}"
        ];
      };
    };
}
