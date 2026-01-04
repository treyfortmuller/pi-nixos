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

      # Map shell completions to the ts alias
      # Run `complete -p tailscale` to discover the completion function bash is
      # using for the original command.
      programs.bash.interactiveShellInit = ''
        complete -o default -F _fzf_path_completion ts
      '';

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
