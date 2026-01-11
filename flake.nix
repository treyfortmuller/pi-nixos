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
            # agenix-cli
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

            # TODO: aliases so I don't have to traverse such a deep attribute tree, probably
            # would want to do this via a readOnly option in the base module.
            # 
            # build-toplevel => config.system.build.toplevel;
            # build-qemu => config.system.build.images.qemu;
            # build-sd-card => config.system.build.images.sd-card;
            options = {
              serenityBuilds = lib.mkOption {
                type = lib.types.lazyAttrsOf lib.types.raw;
                default = {
                  buildToplevel = config.system.build.toplevel;
                  buildQemu = config.system.build.images.qemu;
                  buildSdCard = config.system.build.images.sd-card;
                };
                description = "aliases";
                readOnly = true;
              };
            };

            config = {
            image.modules = {
              # nixosConfigurations.base.config.system.build.images.qemu.passthru.config.services.openssh.enable
              qemu = { config, lib, ... }: {
                services.openssh.enable = lib.mkForce false;
              };
            };


            # Don't attempt to cross compile for now, enforce that the build and host
            # platform are both aarch64
            nixpkgs.hostPlatform = "aarch64-linux";
            nixpkgs.buildPlatform = "aarch64-linux";

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

                makeModulesClosure = x:
                  prev.makeModulesClosure (x // { allowMissing = true; });

                # TODO: might be nicer to use the overlays flake output?

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


# TODO (tff): here's what Im running now:
# nix build .#nixosConfigurations.jerry.config.system.build.images.sd-card --max-jobs 0 --eval-store auto --store ssh-ng://eu.nixbuild.net

# That ended up with what looks like a real build failure:
# modprobe: FATAL: Module sun4i-drm not found in directory /nix/store/x1izpcma5w86i7sicawbz2cn2ydvk846-linux-rpi-6.6.51-stable_20241008-modules/lib/modules/6.6.51

# Now trying to update to 25.11 and see what happens
# 
# Somebody has hit this before:https://github.com/NixOS/nixpkgs/issues/154163
# and https://github.com/NixOS/nixpkgs/issues/111683#issuecomment-968435872

# Upgrading to 25.11 got me here: linux-rpi> modprobe: FATAL: Module dw-hdmi not found in directory /nix/store/fbd6pni3izld7jhdq5db02xq03ardswn-linux-rpi-6.12.47-stable_20250916-modules/lib/modules/6.12.47

# This is a kernel configuration issue, see here for where we require the kernel modules: https://github.com/NixOS/nixpkgs/blob/996536a2301a829b60c1deba51b5533d112f2942/nixos/modules/profiles/all-hardware.nix#L68

# Here's the workaround I'm going to apply:

# https://github.com/NixOS/nixpkgs/issues/126755#issuecomment-869149243

# 
# Ok we built an SD image!
#
# nix copy --from ssh-ng://eu.nixbuild.net /nix/store/w16h6jfvg47nqgxp50qzk42dgmrz5azi-nixos-image-sd-card-25.11.20260107.d351d06-aarch64-linux.img.zst
#
# Pulling it down to my local store now, I killed ~8 CPU hours building this thing (counting all the erroring out builds)