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


---

### Getting SPI enabled in the Pi Device Tree

Unfortunately nixos-hardware provides no options for applying a deviceTree overlay to enable SPI communication on the PI:

```
nix-repl> nixosConfigurations.jerry.options.hardware.raspberry-pi.\"4\".
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".apply-overlays-dtmerge
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".audio
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".backlight
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".bluetooth
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".digi-amp-plus
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".dwc2
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".fkms-3d
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".gpio
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".i2c0
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".i2c1
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".leds
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".poe-hat
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".poe-plus-hat
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".pwm0
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".tc358743
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".touch-ft5406
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".tv-hat
nixosConfigurations.jerry.options.hardware.raspberry-pi."4".xhci
```

Pimoroni has an extensive and probably well-tested high level library for interacting with their displays in python. The `install.sh` is extremely scary and assumes you're running Raspian. Naturally I want to hack in rust, I found this project which looks promising:

https://docs.rs/crate/paperwave/0.2.0/source/README.md

had to jack the source from the docs page because the GH link is a 404

I made a flake-based rust project out of it with support for x86 and aarch64 linux and ran the CLI, building on the target hardware for now. We got results we basically expected.

```
cargo run -- --detect-only --debug

== Probe Report ==
EEPROM: not found
Display: not detected (fallback to 600x448)
I2C buses: none detected
SPI devices: none detected
GPIO chips: /dev/gpiochip0 /dev/gpiochip1
```

I'm going to try enabling gpio, and the i2c devices via the hardware.raspberry-pi."4" options provided by nixos-hardware and we'll see if we get some i2c buses. Then we're going to have to tackle the problem of SPI devices, which I think is going to require some manually applied device tree overlays, yew!

The i2c bus options have an interface clock-frequency setting to configure, I don't know what those should be so we'll leave them at `null` for now, hopefully we'll be able to at least see the devices in `/dev` and spot some relevant kernel modules in `lsmod` - I literally can't find a datasheet for this e-ink display so we'll dig through the source of their python library or its imperative setup script for deets.

Here's a hint, we've got the config.txt referenced here with RPi OS flavored incantations for manipulating the device tree:

https://github.com/pimoroni/inky/blob/main/pyproject.toml#L125-L129

```
configtxt = [
    "dtoverlay=i2c1",
    "dtoverlay=i2c1-pi5",
    "dtoverlay=spi0-0cs"
]
```

I also noticed this `tv-hate.nix` module enables the referenced `spi0-0cs` overlay:

https://github.com/NixOS/nixos-hardware/blob/master/raspberry-pi/4/tv-hat.nix

So I'm going to roll NixOS by throwing the kitchen sink at this thing, we'll enable GPIOs, both i2c buses, and the TV hat. Then we'll check on loaded kernel modules, `/dev` paths, and we'll check back in with `paperwave`'s probe CLI.

After the rebuild boot we've got

```
[pi@jerry:~/paperwave]$ stat /dev/spidev0.1

[pi@jerry:~/paperwave]$ stat /dev/i2c-
i2c-1   i2c-22
```

and 

```
[pi@jerry:~/paperwave]$ lsmod | grep spi
cxd2880_spi            28672  0
dvb_core              176128  1 cxd2880_spi
spidev                 28672  0
spi_bcm2835            28672  0


[pi@jerry:~/paperwave]$ lsmod | grep i2c
i2c_bcm2835            20480  0
i2c_dev                24576  0
```

Getting back to paperwave:

```
[pi@jerry:~/paperwave]$ cargo run -- --detect-only --debug
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.14s
     Running `target/debug/paperwave --detect-only --debug`
== Probe Report ==
EEPROM: not found
Display: not detected (fallback to 600x448)
I2C buses: /dev/i2c-1 /dev/i2c-22
I2C probe results:
  /dev/i2c-1: no response / not available
  /dev/i2c-22: no response / not available
SPI devices: /dev/spidev0.1
GPIO chips: /dev/gpiochip0 /dev/gpiochip1
```

Closer! I've got an idea about the i2c buses, I think we need to make the `pi` a member of the `i2c` group, running this with `sudo` for now:

```
[pi@jerry:~/paperwave/target/debug]$ sudo ./paperwave --detect-only --debug
[sudo] password for pi:
== Probe Report ==
EEPROM: 400x300 colour=7 pcb_variant=10.0 display_variant=24 (Red/Yellow wHAT (JD79668)) (via /dev/i2c-1)
Display: not detected (fallback to 600x448)
I2C buses: /dev/i2c-1 /dev/i2c-22
I2C probe results:
  /dev/i2c-1: found 400x300 colour=7 pcb_variant=10.0 display_variant=24 (Red/Yellow wHAT (JD79668))
  /dev/i2c-22: error Connection timed out (os error 110)
SPI devices: /dev/spidev0.1
GPIO chips: /dev/gpiochip0 /dev/gpiochip1
GPIO labels:
  /dev/gpiochip0 -> gpiochip0 (pinctrl-bcm2711)
  /dev/gpiochip1 -> gpiochip1 (raspberrypi-exp-gpio)
```

LFG we're gonna be in business here.

Trying to update the display for the first time:

```
[pi@jerry:~/paperwave/target/debug]$ sudo ./paperwave
Error: GPIO error: Ioctl to get line handle failed: EBUSY: Device or resource busy
```

Lets see if we can grab some info on who's using my GPIOs: `nix-shell -p libgpiod`

```
[nix-shell:~/paperwave/target/debug]$ sudo gpioinfo -c gpiochip0
gpiochip0 - 58 lines:
	line   0:	"ID_SDA"        	input
	line   1:	"ID_SCL"        	input
	line   2:	"GPIO2"         	input
	line   3:	"GPIO3"         	input
	line   4:	"GPIO4"         	input
	line   5:	"GPIO5"         	input
	line   6:	"GPIO6"         	input
	line   7:	"GPIO7"         	output active-low consumer="spi0 CS1"
	line   8:	"GPIO8"         	output active-low consumer="spi0 CS0"
	line   9:	"GPIO9"         	input
	line  10:	"GPIO10"        	input
	line  11:	"GPIO11"        	input
	line  12:	"GPIO12"        	input
	line  13:	"GPIO13"        	input
	line  14:	"GPIO14"        	input
	line  15:	"GPIO15"        	input
	line  16:	"GPIO16"        	input
	line  17:	"GPIO17"        	input
	line  18:	"GPIO18"        	input
	line  19:	"GPIO19"        	input
	line  20:	"GPIO20"        	input
	line  21:	"GPIO21"        	input
	line  22:	"GPIO22"        	input
	line  23:	"GPIO23"        	input
	line  24:	"GPIO24"        	input
	line  25:	"GPIO25"        	input
	line  26:	"GPIO26"        	input
	line  27:	"GPIO27"        	input
	line  28:	"RGMII_MDIO"    	input
	line  29:	"RGMIO_MDC"     	input
	line  30:	"CTS0"          	input
	line  31:	"RTS0"          	input
	line  32:	"TXD0"          	input
	line  33:	"RXD0"          	input
	line  34:	"SD1_CLK"       	input
	line  35:	"SD1_CMD"       	input
	line  36:	"SD1_DATA0"     	input
	line  37:	"SD1_DATA1"     	input
	line  38:	"SD1_DATA2"     	input
	line  39:	"SD1_DATA3"     	input
	line  40:	"PWM0_MISO"     	input
	line  41:	"PWM1_MOSI"     	input
	line  42:	"STATUS_LED_G_CLK"	output consumer="ACT"
	line  43:	"SPIFLASH_CE_N" 	input
	line  44:	"SDA0"          	input
	line  45:	"SCL0"          	input
	line  46:	"RGMII_RXCLK"   	input
	line  47:	"RGMII_RXCTL"   	input
	line  48:	"RGMII_RXD0"    	input
	line  49:	"RGMII_RXD1"    	input
	line  50:	"RGMII_RXD2"    	input
	line  51:	"RGMII_RXD3"    	input
	line  52:	"RGMII_TXCLK"   	input
	line  53:	"RGMII_TXCTL"   	input
	line  54:	"RGMII_TXD0"    	input
	line  55:	"RGMII_TXD1"    	input
	line  56:	"RGMII_TXD2"    	input
	line  57:	"RGMII_TXD3"    	input

[nix-shell:~/paperwave/target/debug]$ sudo gpioinfo -c gpiochip1
gpiochip1 - 8 lines:
	line   0:	"BT_ON"         	output consumer="shutdown"
	line   1:	"WL_ON"         	output
	line   2:	"PWR_LED_OFF"   	output active-low consumer="PWR"
	line   3:	"GLOBAL_RESET"  	output
	line   4:	"VDD_SD_IO_SEL" 	output consumer="vdd-sd-io"
	line   5:	"CAM_GPIO"      	output consumer="cam1_regulator"
	line   6:	"SD_PWR_ON"     	output consumer="regulator-sd-vcc"
	line   7:	"SD_OC_N"       	input
```

Ok we'll probably need better logs from paperwave about which GPIO chip and line is "busy" to dive into that, no problem. Lets table that for now. Checking on the groups which own the devices I'm interested in:

```
[nix-shell:~/paperwave/target/debug]$ ls -la /dev | grep "spi\|gpio\|i2c"
crw-rw----  1 root gpio  254,   0 Nov 16 19:16 gpiochip0
crw-rw----  1 root gpio  254,   1 Nov 16 19:16 gpiochip1
crw-rw----  1 root gpio  237,   0 Nov 16 19:16 gpiomem
crw-rw----  1 root i2c    89,   1 Nov 16 19:16 i2c-1
crw-rw----  1 root i2c    89,  22 Nov 16 19:16 i2c-22
crw-------  1 root root  153,   0 Nov 16 19:16 spidev0.1
```

Ok so we need to be in gpio, i2c, and then the spi device is root:root so we'll need to take special care of that. Gonna apply this diff turning off i2c0 since it was explicitly called out in the inky python library setup:

```
diff --git a/jerry/configuration.nix b/jerry/configuration.nix
index 22e9370..b233188 100644
--- a/jerry/configuration.nix
+++ b/jerry/configuration.nix
@@ -46,6 +46,10 @@
     extraGroups = [
       "wheel"
       "networkmanager"
+
+      # TODO: split this out into wHAT configuration for the inky
+      "gpio"
+      "i2c"
     ];

     # Can switch to nix-sops if I end up needing to ship more secrets
@@ -62,6 +66,10 @@
     htop
     jq
     git
+
+    # TODO: inky things, split these out
+    i2c-tools
+    libgpiod
   ];

   # Configure network proxy if necessary
@@ -144,11 +152,6 @@
   # hardware.raspberry-pi."4".xhci
   hardware.raspberry-pi."4" = {
     gpio.enable = true;
-
-    i2c0 = {
-      enable = true;
-      frequency = null; # TODO: what should this be?
-    };

     i2c1 = {
       enable = true;
```

Ok those changes have taken place:

```
[pi@jerry:~]$ groups pi
pi : users wheel networkmanager i2c gpio

[pi@jerry:~]$ i2cdetect -F 1
Functionalities implemented by /dev/i2c-1:
I2C                              yes
SMBus Quick Command              yes
SMBus Send Byte                  yes
SMBus Receive Byte               yes
SMBus Write Byte                 yes
SMBus Read Byte                  yes
SMBus Write Word                 yes
SMBus Read Word                  yes
SMBus Process Call               yes
SMBus Block Write                yes
SMBus Block Read                 no
SMBus Block Process Call         no
SMBus PEC                        yes
I2C Block Write                  yes
I2C Block Read                   yes
SMBus Host Notify                no
10-bit addressing                no
Target mode                      no

[pi@jerry:~]$ i2cdetect -F 22
Error: Could not open file `/dev/i2c-22' or `/dev/i2c/22': No such file or directory
```

i2c-22 is gone now, I have a hunch enabling those i2c buses might have been stomping on extra GPIOs that the paperwave needs.

Also, we can query a gpiochip without elevating to sudo now:

```
[pi@jerry:~]$ gpioinfo -c gpiochip0
gpiochip0 - 58 lines:
	line   0:	"ID_SDA"        	input
	line   1:	"ID_SCL"        	input
	line   2:	"GPIO2"         	input
	line   3:	"GPIO3"         	input
...
```

Finally found a fucking datasheet for this thing, its called a JD79668

https://files.waveshare.com/wiki/4.2inch%20e-Paper%20Module%20(G)/4.2inch_e-Paper_(G).pdf

Still getting the resource busy issue, reading through the source in `paperwave` I can see we're trying to manipulate 4 different GPIO pins: gpiochip0 line 8, 22, 27, and 17. These correspond with the docs from Pimoroni on the pinout for the display here: https://pinout.xyz/pinout/inky_what

I wasn't getting clear error messages from `paperwave` so I narrowed down the problem child by manually manipulating GPIOs with `gpioset`

```
[pi@jerry:~/paperwave/target/debug]$ sudo gpioset -c gpiochip0 8=on
[sudo] password for pi:
gpioset: unable to request lines on chip '/dev/gpiochip0': Device or resource busy

[pi@jerry:~/paperwave/target/debug]$ sudo gpioset -c gpiochip0 9=on
^C

[pi@jerry:~/paperwave/target/debug]$ sudo gpioset -c gpiochip0 22=on
^C

[pi@jerry:~/paperwave/target/debug]$ sudo gpioset -c gpiochip0 27=on
^C

[pi@jerry:~/paperwave/target/debug]$ sudo gpioset -c gpiochip0 17=on
^C
```

So pin 8 is our problem child, which is supposed to be the SPI0 chip select pin... So whats happening here is the spi driver the kernel loaded is laying claim to pin 8 as a chip select pin, but paperwave wants to handle chip selection manually, so its trying to manipulate it as a plain-old GPIO. This has to do with the TV hat device tree overlay we applied...

I'm pretty sure that the [`spi0-0cs-overlay.dts`](https://github.com/raspberrypi/linux/blob/rpi-6.1.y/arch/arm/boot/dts/overlays/spi0-0cs-overlay.dts) checked into the raspberrypi/linux repo sets no chip select pins, `*-1cs` sets one chip select pin, and `*-2cs` sets two. Inspecting the TV hat module, we can see both gpio lines 7 and 8 get set as chip select. So all we've got to do is disable that TV hat overlay, and instead apply our own device tree overlay (out of band of the nixos-hardware options) which perfectly matches the raspberrypi "upstream" overlay with 0 chip select chips. The kernel will get its hands off that GPIO line and the "Device busy" issue should go away.

I ended up modifying the TV Hat overlay to exclude the chip select chips and the kernel is hands-off the GPIOs that paperwave needs now, nice. We get a new error around perms:

```
[pi@jerry:~/paperwave/target/debug]$ ./paperwave
Ready to roll...
== Probe Report ==
EEPROM: 400x300 colour=7 pcb_variant=10.0 display_variant=24 (Red/Yellow wHAT (JD79668)) (via /dev/i2c-1)
Display: JD79668 (400x300)
I2C buses: /dev/i2c-1
I2C probe results:
  /dev/i2c-1: found 400x300 colour=7 pcb_variant=10.0 display_variant=24 (Red/Yellow wHAT (JD79668))
SPI devices: /dev/spidev0.0 /dev/spidev0.1
GPIO chips: /dev/gpiochip0 /dev/gpiochip1
GPIO labels:
  /dev/gpiochip0 -> gpiochip0 (pinctrl-bcm2711)
  /dev/gpiochip1 -> gpiochip1 (raspberrypi-exp-gpio)

Creating the display... the display spec we have is: Some(Jd79668 { width: 400, height: 300 })
Error: IO error: Permission denied (os error 13)
```

Which I believe is because the SPI devices are owned by `root`:

```
[pi@jerry:~/paperwave/target/debug]$ ls -ls /dev/ | grep spi
0 crw------- 1 root root  153,   0 Nov 16 22:26 spidev0.0
0 crw------- 1 root root  153,   1 Nov 16 22:26 spidev0.1
```

I think the right way to fix that is to get the spi devices to be owned by some other group and then add the pi user to that group. For now, `sudo`. We get further!

```
Creating the display... the display spec we have is: Some(Jd79668 { width: 400, height: 300 })
Error: Unsupported resolution 400x300
```

Ok hell ya, this is just a failure in application code, the `paperwave` library doesn't support my specific model of e-ink display so we'll have to go wrench on it, but I think all the hardware might be doing the right things now. We'll go back to that `pi` user perms on SPI devices.

We'll cook up a udev rule to apply here, first inspecting some attributes of this device to match on:

```
[pi@jerry:~]$ udevadm info -a -n /dev/spidev0.0

  looking at device '/devices/platform/soc/fe204000.spi/spi_master/spi0/spi0.0/spidev/spidev0.0':
    KERNEL=="spidev0.0"
    SUBSYSTEM=="spidev"
    DRIVER==""
    ATTR{power/control}=="auto"
    ATTR{power/runtime_active_kids}=="0"
    ATTR{power/runtime_active_time}=="0"
    ATTR{power/runtime_enabled}=="disabled"
    ATTR{power/runtime_status}=="unsupported"
    ATTR{power/runtime_suspended_time}=="0"
    ATTR{power/runtime_usage}=="0"
```

We'll ship this snippet to the config

```
  # TODO (tff): this is inky specific
  users.groups = { spi = { }; };
  services.udev.extraRules = ''
    # Add the spidev0.0 device to a group called spi (by default its root) so that our user
    # can be added to the group and make use of the device without elevated perms.
    SUBSYSTEM=="spidev", KERNEL=="spidev0.0", GROUP="spi", MODE="0660"
  '';
```

And we'll also need to add `users.users.pi.extraGroups = [ "spi" ];` - this is going to need a refactor after we get this done to factor out the complexity of the inky-specific configuration into its own module, probably behind a `mkEnableOption`, but we'll cross that bridge after we've got some ink on the display.

Say it again bart! `nixos-rebuild boot --flake .#`

Now we're cooking with gas

```
[pi@jerry:~]$ ll /dev/ | grep spi
crw-rw---- 1 root spi   153,   0 Nov 16 23:00 spidev0.0

[pi@jerry:~/pi-nixos]$ groups pi
pi : users wheel networkmanager spi i2c gpio
```

So now we need to confirm we made it past the permission denied error in `paperwave`

```
Creating the display... the display spec we have is: Some(Jd79668 { width: 400, height: 300 })
Error: Unsupported resolution 400x300
```

Money... time to just hack on paperwave to support my 400x300 e-ink display.


