### Mainline SD Installer

Due to ["hardware limitations"](https://nixos.wiki/wiki/NixOS_on_ARM#Installation) the NixOS ISOs shipped on the Downloads page are not going to work, so we want the SD card image files (a `.img`) instead. Its about 1.4GB.

I grabbed a recent headless build of 25.05 from Hydra [here](https://hydra.nixos.org/build/313292115).

My tool of choice for thumbdrive or SD card imaging is [`caligula`](https://github.com/ifd3f/caligula), less error prone than `dd` and everybody loves a TUI:

```
nix-shell -p caligula

caligula burn ./nixos-image-sd-card-25.05.812778.3acb677ea67d-aarch64-linux.img.zst
```

This thing will decompress it for us, verify a hash, elevate to `sudo` when you forgot to do it, and warn you very clearly when you're about to obliterate all the data on a disk.

Plugged that shit in and booted, literally zero hassle on mainline NixOS targeting aarch64. The device tree will not be correct so we won't be able to use any peripherals out of the box with mainline NixOS.

Thankfully we've got a `nixos-hardware` entry for the RPi 4 [here](https://github.com/NixOS/nixos-hardware/tree/master/raspberry-pi/4), its extensive.

### Install

The installer brought up networking as evidenced by `ip a`

First I'm gonna set a password for the nixos user we've dropped into with `passwd`

Then we're going to nixos-generate-config, and just `nixos-rebuild boot` and `sudo reboot now`.

[These notes](https://nixos.wiki/wiki/NixOS_on_ARM#NixOS_installation_.26_configuration) make it clear we should go this route on ARM devices rather than using the `nixos-install` script we're used to for desktop installations.

The config that is generated needs a couple changes, I'm going to add a password to the user, add a hostname, enable NetworkManager and OpenSSH. Now we just need wifi setup so we can download the things we need for the builds triggered by the generation swap.

On the minimal installer, NetworkManager is not available, so wireless configuration must be performed manually. To configure the wifi, first start `wpa_supplicant` with `sudo systemctl start wpa_supplicant`, then run `wpa_cli`. For most home networks it'll look like this:

```
add_network
0
set_network 0 ssid "myhomenetwork"
OK
set_network 0 psk "mypassword"
OK
enable_network 0
OK
```

Alright now we've got internet access, before we do the rebuild boot we should make sure we have swap enabled because the Pi I'm working with only has 1GB of RAM.

```
swapon --show
```

indicates no swap files at the moment.

We're going to enable one imperatively right now, and then add the same configuration to the `hardware-configuration.nix` declaratively so it persists through the rebuild.

The `hardware-configuration.nix` mod will look like

```nix
swapDevices = [
  {
    device = "/swapfile";
    size = 4096;  # 4 GB
  }
];
```

I think after I get out of the habit of building on-target for this particular model of Pi, we can get away from doing this entirely.

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

---

Now im gonna hardline this to my host and try to SSH in sowe can stop staring at a 4 inch screen

On the pi I set the eth interface to be unmanaged in NetworkManager so we can manually add an ip

```
nmcli dev set end0 managed no

ip addr add 192.168.10.7/24 dev end0
```

and similar on my host

```
13:33:30 (~) $ nmcli dev set enp0s20f0u1 managed no

13:34:21 (~) $ sudo ip addr add 192.168.10.8/24 dev enp0s20f0u1
```

Easy money:

```
13:34:44 (~) $ ping 192.168.10.7
PING 192.168.10.7 (192.168.10.7) 56(84) bytes of data.
64 bytes from 192.168.10.7: icmp_seq=1 ttl=64 time=0.899 ms
64 bytes from 192.168.10.7: icmp_seq=2 ttl=64 time=0.448 ms
```

We're in:

```
ssh alice@192.168.10.7
```

Now we'll copy off the configuration.nix and the hardware-configuration.nix, and include them in our flake-based, source controlled configuration for pis. We'll add in the nixos-hardware modules for the RPi4 in hopes to get a wider section of the device tree up and running from the start.

#### SSH Access

For a fresh NixOS install we'll add a password to the `nixos` user with `passwd` and then try to SSH onto this thing from my host. Then we'll go ship a new NixOS configuration to the device and nixos-rebui


#### Deploying the flake-based configuration

Note I had to reconnect to wifi (this time we get to use `nmcli` because we deployed NetworkManager on the install configuration, no more of that `wpa_supplicant` nonsense).

Because I don't actually have an aarch64 build machine available at the moment, we're going to have to build on device. I literally `scp`'ed this whole repo over to the pi, and then

```
sudo nixos-rebuild boot --flake .#jerry

sudo reboot now
```

That worked a charm. Static IP is set automatically, new user and password were setup, SSH success right away, and NetworkManager remembered our wifi connection.

### Resources

* This is an alternative project for more complete RPi NixOS support, might be worth looking at in the future, its hardware + package overlays + kernel/firmware considerations + SD image builds, the whole nine: https://github.com/nvmd/nixos-raspberrypi/tree/develop