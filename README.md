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

on an aarch64 build server somewhere, pull down the sdImage, and flash new boards that way, then just build system-configurations offboard after the fact and use deploy-rs (or nixos-anywhere?) or some other mechanism to roll upgrades to networked devices, probably don't want to ever rev configurations on the device with 1GB of RAM. Some info on that approach [here](https://nixos.wiki/wiki/NixOS_on_ARM#Build_your_own_image_natively).

Lets get to burning:

```
caligula burn ./nixos-image-sd-card-25.05.812778.3acb677ea67d-aarch64-linux.img.zst
```

This thing will decompress it for us, verify a hash, elevate to sudo when you forgot to do it, and warn you very clearly when you're about to obliterate all the data on a disk.

Plugged that shit in and booted and we're in, literally zero hassle on mainline aarch64 everything. Of course we know nothing about if the device tree is correct or any of our peripherals are working but still.

Thankfully we've got a `nixos-hardware` entry for the RPi 4 [here](https://github.com/NixOS/nixos-hardware/tree/master/raspberry-pi/4), its extensive.

#### Install

The installer brought up networking as evidenced by `ip a`

Firts I'm gonna set a password for the nixos user we've dropped into with passwd

Then we're going to nixos-generate-config, and just nixos-reuild boot and reboot

https://nixos.wiki/wiki/NixOS_on_ARM#NixOS_installation_.26_configuration

these notes make it clear we should go this route on ARM devices rather than using the nixos-install script we're used to for desktop installations.

The config thats get generated needs a couple changes, Im going to add a password to the user, add a hostname, enable NetworkManager and OpenSSH. Now we just need wifi setup so we can download the things we need for the builds triggered by the generation swap.

On the minimal installer, NetworkManager is not available, so configuration must be performed manually. To configure the wifi, first start wpa_supplicant with sudo systemctl start wpa_supplicant, then run wpa_cli. For most home networks, you need to type in the following commands:

add_network
0
set_network 0 ssid "myhomenetwork"
OK
set_network 0 psk "mypassword"
OK
enable_network 0
OK

Alright now we've got internet access, before we do the rebuild boot we should make sure we have swap enabled cuz this pi only has 1 GB of RAM.

```
swapon --show
```

indicates no swap files at the moment.

We're going to enable one imperatively right now, and then add the same configuration to the hardware-configuration.nix declaratively so it persists through the rebuild.

The hardware-configuration.nix mod will look like

```
swapDevices = [
  {
    device = "/swapfile";
    size = 4096;  # 4 GB
  }
];
```

I think after I get out of the habit of building on-target for this particular model of Pi, we can get away from doing this entirely, this will wear SD cards faster.

Now to set this up imperatively before the first rebuild:

---


1. Decide how much swap you want

Example: 2G

sudo fallocate -l 2G /swapfile


If fallocate isn’t available or you want guaranteed zeroed bytes:

sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress

2. Set correct permissions

Swap must not be world-readable.

sudo chmod 600 /swapfile

3. Format it as swap
sudo mkswap /swapfile

4. Enable it now
sudo swapon /swapfile


Check:

swapon --show
free -h


---


Ok now we'll rebuild boot and reboot

```
sudo nixos-rebuild boot
sudo reboot now
```

that succeeded lets gooo...




#### SSH Access

For a fresh NixOS install we'll add a password to the `nixos` user with `passwd` and then try to SSH onto this thing from my host. Then we'll go ship a new NixOS configuration to the device and nixos-rebui

### Resources

* This is an alternative project for more complete RPi NixOS support, might be worth looking at in the future, its hardware + package overlays + kernel/firmware considerations + SD image builds, the whole nine: https://github.com/nvmd/nixos-raspberrypi/tree/develop


