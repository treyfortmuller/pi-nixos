### Aspiration

Ultimately I'd like to get this to a point where I can run something to the effect of

```
nix build '.#nixosConfigurations.rpi-example.config.system.build.sdImage'
```

on an aarch64 build server somewhere, pull down the sdImage, and flash new boards that way, then just build system-configurations offboard after the fact and use deploy-rs (or nixos-anywhere?) or some other mechanism to roll upgrades to networked devices, probably don't want to ever rev configurations on the device with 1GB of RAM. Some info on that approach [here](https://nixos.wiki/wiki/NixOS_on_ARM#Build_your_own_image_natively).

TODO