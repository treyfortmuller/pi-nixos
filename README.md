# pi-nixos
NixOS configurations for the RPi SBC

### Notes

Due to ["hardware limitations"](https://nixos.wiki/wiki/NixOS_on_ARM#Installation) the NixOS ISOs shipped on the Downloads page are not going to work, so we want the SD card image files (.img) instead. Its about 1.4GB.

I grabbed a recent build of 25.05 from Hydra here: https://hydra.nixos.org/build/313292115

Trying out this fun little TUI for imaging disks: https://github.com/ifd3f/caligula

Lots of useful features in this thing, I hate `dd`

```
nix-shell -p caligula
```

Ultimately I'd like to get this to a point where I can run something to the effect of

```
nix build '.#nixosConfigurations.rpi-example.config.system.build.sdImage'
```

on an aarch64 build server somewhere, pull down the sdImage, and flash new boards that way, then just build system-configurations offboard after the fact and use deploy-rs or some other mechanism to roll upgrades to networked devices, probably don't want to ever rev configurations on the device with 1GB of RAM. Some info on that approach [here](https://nixos.wiki/wiki/NixOS_on_ARM#Build_your_own_image_natively).

Lets get to burning:

```
caligula burn ./nixos-image-sd-card-25.05.812778.3acb677ea67d-aarch64-linux.img.zst
```

This thing will decompress it for us, verify a hash, elevate to sudo when you forgot to do it, and warn you very clearly when you're about to obliterate all the data on a disk.






