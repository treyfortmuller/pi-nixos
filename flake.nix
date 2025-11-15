{
  description = "NixOS on RPi, targeting RPi4 Model B for now.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    flake-utils.url = "github:numtide/flake-utils";
    # nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self
    , nixpkgs
    , nixos-hardware
    , flake-utils
      # , nixpkgs-unstable
    , ...
    }@inputs:
    let
      system = "x86_64-linux";
    in
    {
      # Useful for burning SD cards and hacking on these configurations
      devShells.${system}.default =
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.mkShell {
          packages = [
            pkgs.caligula
            pkgs.nixpkgs-fmt
          ];
        };

      nixosConfigurations = {
        # Our hostname naming conventions for pi projects will be... Seinfeld characters, here's a list:
        # 
        # Main Characters
        #   Jerry Seinfeld — Comedian, neat freak, observer of life’s absurdities.
        #   George Costanza — Neurotic, insecure, perpetually disgruntled best friend.
        #   Elaine Benes — Jerry’s ex, confident but chaotic, works in publishing.
        #   Cosmo Kramer — Eccentric neighbor with wild ideas and stranger entrances.
        # Major Recurring Characters
        #   Newman — Jerry’s nemesis; postal worker, mischievous.
        #   Morty Seinfeld — Jerry’s father; former raincoat salesman.
        #   Helen Seinfeld — Jerry’s mother; doting and anxious.
        #   Frank Costanza — George’s explosive father (serenity now!).
        #   Estelle Costanza — George’s shrill, melodramatic mother.
        #   Uncle Leo — Jerry’s excitable uncle; “Jerry! Hello!”

        jerry = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            # self.nixosModules.default
            nixos-hardware.nixosModules.raspberry-pi-4
            ./jerry/configuration.nix
            ./jerry/hardware-configuration.nix
          ];
          specialArgs = {
            inherit inputs;
          };
        };
      };

      # nixosModules = {
      #   # The base configuration to be depended on by privately-managed machines
      #   default =
      #     { ... }:
      #     {
      #       imports = [
      #         home-manager.nixosModules.home-manager
      #         ./base.nix
      #         ./nvidia.nix
      #       ];

      #       # final and prev, a.k.a. "self" and "super" respectively. This overlay
      #       # makes 'pkgs.unstable' available.
      #       nixpkgs.overlays = [
      #         (final: prev: {
      #           unstable = import nixpkgs-unstable {
      #             system = final.system;
      #             config.allowUnfree = true;
      #           };

      #           # See https://github.com/NixOS/nixpkgs/issues/440951 for bambu-studio, was running into
      #           # crashes using networking features in bambu-studio. 25.05's derivation builds it from source
      #           # whereas this uses the appimage and is a more recent version of the slicer.
      #           bambu-studio = prev.appimageTools.wrapType2 rec {
      #             name = "BambuStudio";
      #             pname = "bambu-studio";
      #             version = "02.03.00.70";
      #             ubuntu_version = "24.04_PR-8184";

      #             src = prev.fetchurl {
      #               url = "https://github.com/bambulab/BambuStudio/releases/download/v${version}/Bambu_Studio_ubuntu-${ubuntu_version}.AppImage";
      #               sha256 = "sha256:60ef861e204e7d6da518619bd7b7c5ab2ae2a1bd9a5fb79d10b7c4495f73b172";
      #             };

      #             profile = ''
      #               export SSL_CERT_FILE="${prev.cacert}/etc/ssl/certs/ca-bundle.crt"
      #               export GIO_MODULE_DIR="${prev.glib-networking}/lib/gio/modules/"
      #             '';

      #             extraPkgs = pkgs: with pkgs; [
      #               cacert
      #               glib
      #               glib-networking
      #               gst_all_1.gst-plugins-bad
      #               gst_all_1.gst-plugins-base
      #               gst_all_1.gst-plugins-good
      #               webkitgtk_4_1
      #             ];
      #           };
      #         })

      #         # TODO: anything good in here?
      #         # nixpkgs-wayland.overlay
      #       ];
      #     };
      #   };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
