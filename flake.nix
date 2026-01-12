{
  description = "NixOS on RPi, targeting RPi4 Model B for now.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    flake-utils.url = "github:numtide/flake-utils";
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.darwin.follows = ""; # saves some resources on Linux
    };

    # Projects
    weatherframe = {
      url = "github:treyfortmuller/weatherframe";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    openwx = {
      url = "github:treyfortmuller/openwx";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tatted = {
      url = "github:treyfortmuller/tatted";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
      flake-utils,
      vscode-server,
      agenix,
      weatherframe,
      openwx,
      tatted,
      ...
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
          packages = with pkgs; [
            caligula
            nixfmt-tree
            agenix.packages.${system}.default
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

        # Baseline RPi 4 Model B, no peripheral devices enabled, no device tree overlays, vanilla
        # as possible just to boot NixOS on a new system. SD installers of this OS config
        # are useful for testing and bringup.
        base = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            self.nixosModules.default

            # Using the jerry hardware config for now since I only have one pi
            ./jerry/hardware-configuration.nix
          ];
          specialArgs = {
            inherit inputs;
          };
        };

        # Jerry is an RPi 4 Model B running a Pimoroni 4-color wHAT e-ink display for
        # fun and profit, except there's no profit and I rewrote the e-ink controller driver
        # from scratch so there's a lot of suffering too.
        jerry = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            self.nixosModules.default
            ./jerry/configuration.nix
            ./jerry/hardware-configuration.nix
          ];
          specialArgs = {
            inherit inputs;
          };
        };
      };

      nixosModules = {
        default =
          { config, lib, ... }:
          {
            # All modules should be added to default modules, all config that does not need to be
            # enabled by default should be hidden behind a mkEnableOption. Simply importing a module
            # should be a no-op to the resultant config, except for the absolute basics included in base.nix.
            #
            # For this project we'll keep all options defined in-tree under `config.serenity`, as in, "serenity now!"
            imports = [
              nixos-hardware.nixosModules.raspberry-pi-4
              vscode-server.nixosModules.default
              agenix.nixosModules.default
              ./modules/base.nix
              ./modules/dev.nix
              ./modules/inky.nix
              ./modules/weatherframe.nix
              ./modules/tailscale.nix
            ];

            # nixos-generators is pretty much totally rolled into upstream nixpkgs as far as I can tell,
            # but one nice this it does is alias the image formats we can build such that we don't have to
            # remember how to traverse a huge attribute tree to get to the derivation we want.
            #
            # e.g. config.formats.sd-card -> config.system.build.images.sd-card;
            options = {
              formats = lib.mkOption {
                type = lib.types.lazyAttrsOf lib.types.raw;
                default = {
                  toplevel = config.system.build.toplevel;
                  qemu = config.system.build.images.qemu;
                  sd-card = config.system.build.images.sd-card;
                };
                description = "Aliases to the supported image formats we can build for this NixOS configuration.";
                readOnly = true;
              };
            };

            config = {
              # Is this shit not the coolest? These are modules to include only during the build of these output formats.
              # See .#nixosConfigurations.<foo>.config.system.build.images. for the full list of supported image format.
              image.modules = {
                # Note, each image format has a "passthru.config" so you can probe on the repl at the "final" configuration
                # after the config has been extended with these modules.
                #
                # i.e. base.config.system.build.images.qemu.passthru.config...
                #
                # TODO: I actually need KVM-enabled aarch64 builds in nixbuild.net for this
                qemu =
                  { modulesPath, ... }:
                  {
                    imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
                    virtualisation = {
                      cores = 2;
                      memorySize = 2048;
                    };
                  };

                sd-card =
                  { config, lib, ... }:
                  {
                    # Don't attempt to cross compile for now, enforce that the build and host
                    # platform are both aarch64
                    nixpkgs.hostPlatform = "aarch64-linux";
                    nixpkgs.buildPlatform = "aarch64-linux";
                  };
              };

              # final and prev, a.k.a. "self" and "super" respectively. This overlay
              # makes 'pkgs.unstable' available.
              nixpkgs.overlays = [
                (final: prev: {
                  # If we need some unstable packages, can provide an overlay with unstable
                  # on top of the pinned stable version, etc.
                  #
                  # unstable = import nixpkgs-unstable {
                  #   system = final.system;
                  #   config.allowUnfree = true;
                  # };

                  # See this ticket for more details: https://github.com/NixOS/nixpkgs/issues/126755#issuecomment-869149243
                  # The RPi kernel will be missing modules that are required by a typical NixOS build, we can safely
                  # ignore that.
                  makeModulesClosure = x: prev.makeModulesClosure (x // { allowMissing = true; });

                  # Here's where derivations for our own services are going to go...
                  weatherframe = weatherframe.packages.${final.system}.default;
                  openwx = openwx.packages.${final.system}.default;
                  tatted = tatted.packages.${final.system}.default;
                })
              ];

            };

          };
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
    };
}
