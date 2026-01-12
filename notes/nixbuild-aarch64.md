# nixbuild.net for aarch64 builds

Here'w what I started with:

```
nix build .#nixosConfigurations.jerry.config.system.build.images.sd-card --max-jobs 0 --eval-store auto --store ssh-ng://eu.nixbuild.net
```

That ended up with what looks like a real build failure:

```
modprobe: FATAL: Module sun4i-drm not found in directory /nix/store/x1izpcma5w86i7sicawbz2cn2ydvk846-linux-rpi-6.6.51-stable_20241008-modules/lib/modules/6.6.51
```

Blindly trying to update to NixOS 25.11 to see what happens, it was on my todo list anyway.

Turns out somebody has hit this before:
* https://github.com/NixOS/nixpkgs/issues/154163
* https://github.com/NixOS/nixpkgs/issues/111683#issuecomment-968435872

Upgrading to 25.11 got me here: 

```
linux-rpi> modprobe: FATAL: Module dw-hdmi not found in directory /nix/store/fbd6pni3izld7jhdq5db02xq03ardswn-linux-rpi-6.12.47-stable_20250916-modules/lib/modules/6.12.47
```

So we're just complaining about a _different_ missing kernel module in the `linux-rpi-6.12` kernel.

This is a kernel configuration issue, see [here](https://github.com/NixOS/nixpkgs/blob/996536a2301a829b60c1deba51b5533d112f2942/nixos/modules/profiles/all-hardware.nix#L68) for where a typical NixOS build requires its kernel modules.

The workaround I'm going to apply can be found [here](https://github.com/NixOS/nixpkgs/issues/126755#issuecomment-869149243).


Ok we built an SD image! The build succeeded. Between the failed and succeeded builds I killed ~8 CPU hours of my 25 free CPU hours building this thing. 

I built this with a `--store` arg pointing the remote store, no biggy just need to copy down the system closure to my machine from the remote store. Using `nix copy` for this.

```
nix copy --from ssh-ng://eu.nixbuild.net /nix/store/w16h6jfvg47nqgxp50qzk42dgmrz5azi-nixos-image-sd-card-25.11.20260107.d351d06-aarch64-linux.img.zst -vvvv
```

That failed... with an infuriating hang on nix copy:

```
debug1: Sending command: nix-daemon --stdio
debug1: pledge: fork
debug1: set_sock_tos: invalid TOS 2147483647
don't know how to build these paths:
  /nix/store/w16h6jfvg47nqgxp50qzk42dgmrz5azi-nixos-image-sd-card-25.11.20260107.d351d06-aarch64-linux.img.zst
```

fuck.

Trying again with an equivalent invocation using the old-school `nix-copy-closure` CLI and that worked. Seems like the maintainer of nixbuild.net already knows about these issues: https://github.com/nixbuild/feedback/issues/7

I'm off to the races. Using `caligula burn` to burn the SD card. This thing boots, lets gooooo.
