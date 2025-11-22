# Pimoroni e-ink displays on a NixOS Raspberry Pi

The [Pimoroni Inky wHAT (wide-hat) 4-color e-ink display](https://shop.pimoroni.com/products/inky-what?variant=55696156885371) requires
* i2c comms for its EEPROM
* SPI for control of the display itself
* A couple more GPIOs for manually handling the SPI chip-select and other display functions

If you follow the advice of the manufacturer, you should be using Raspberry Pi OS and their python library. The python library ships with this [`install.sh`](https://github.com/pimoroni/inky/blob/main/install.sh) script to do the setup that we're going to suffer through ourselves. If you're any more allergic to imperative system configuration than I am, this ~400 line script will send you to the hospital.

So instead, we'll do it the hard way, the declarative way, the hermitic way (please stop me).

### `nixos-hardware` options

Our saving grace for device tree manipulation to get all the peripherals we need up and running might come from the [`nixos-hardware`](https://github.com/NixOS/nixos-hardware) project which is "a collection of NixOS modules covering hardware quirks". They've got a set of modules for each of the five models of Raspberry Pi available at the time of writing. I've included the modules in my flake-based system configuration for this device already, but haven't explored the options. `nixos-hardware` doesn't have the nice auto-generated docs for module options that NixOS and `home-manager` do so we'll use the REPL to explore them and then dig into the source if we need to:

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

Ok some promising stuff in here. Before we dig in I'd like to get a baseline for interacting with the display. I already cooked up other parts of the project I have in mind for this e-ink display in rust, so we'll check for crates built around Inky displays. I found this project called [`paperwave`](https://docs.rs/crate/paperwave/0.2.0/source/README.md) which is still on `crates.io`, but the GitHub link is a 404. It claims to support two different e-ink controller drivers for different models of Inky displays (although neither of which are the one I have), it has a CLI I can use to test with, and its well-documented. With the repo being torn down I had to grab the source from the `docs.rs` interface which was slightly annoying.

I made a flake-based rust project out of it with support for x86_64 and aarch64 linux and ran the CLI, building on the target hardware (the Pi) for now. We got results we expected with the `paperwave` CLI:

```
cargo run -- --detect-only --debug

== Probe Report ==
EEPROM: not found
Display: not detected (fallback to 600x448)
I2C buses: none detected
SPI devices: none detected
GPIO chips: /dev/gpiochip0 /dev/gpiochip1
```

Next we'll enable `gpio`, as well as the `i2c0` and `i2c1` devices via the `hardware.raspberry-pi."4"` options provided by the `nixos-hardware` modules. Then we're going to have to tackle the problem of SPI communication, which I think is going to require some manually applied device tree overlays, yew!

The i2c bus options have a per-interface `clock-frequency` setting to configure, I don't know what those should be so we'll leave them at `null` for now. Hopefully we'll be able to at least see the devices in `/dev` and spot some relevant kernel modules in `lsmod` - I'm struggling to find a datasheet for this e-ink display controller so I might have to dig through the source of the Pimoroni python library or its install  script for details.

Looking at the [`pyproject.toml`](https://github.com/pimoroni/inky/blob/main/pyproject.toml#L125-L129) in the Pimoroni python library I discovered a hint. We've got the `config.txt` referenced here with RPi OS flavored incantations for manipulating the device tree:

```toml
configtxt = [
    "dtoverlay=i2c1",
    "dtoverlay=i2c1-pi5",
    "dtoverlay=spi0-0cs"
]
```

I also noticed this [`tv-hat.nix` module](https://github.com/NixOS/nixos-hardware/blob/master/raspberry-pi/4/tv-hat.nix) in `nixos-hardware` references the same `spi0-0cs` overlay.

So I'm going to roll NixOS by throwing the kitchen sink at this thing and exploring the results at runtime, we'll enable GPIOs, both i2c buses, and the TV hat. Then we'll check on loaded kernel modules, `/dev` paths, and we'll check back in with `paperwave`'s probe CLI.

After the rebuild boot we've got a SPI device and i2c buses

```
[pi@jerry:~/paperwave]$ stat /dev/spidev0.1

[pi@jerry:~/paperwave]$ stat /dev/i2c-
i2c-1   i2c-22
```

as well as some relevant kernel modules to match

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

That promising, at least the module options are affecting the device tree as expected, getting back to `paperwave`:

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

LFG we're gonna be in business here. `paperwave` was able to read the device information off of the EEPROM and we seem to have at least discovered all the required peripherals. Running the `paperwave` CLI again but this time actually try to update the display to a test image that the CLI generates, again with `sudo`:

```
[pi@jerry:~/paperwave/target/debug]$ sudo ./paperwave
Error: GPIO error: Ioctl to get line handle failed: EBUSY: Device or resource busy
```

Lets see if we can grab some info on who's using my GPIOs with `gpioinfo`, its shipped with `libgpiod`:

```
[pi@jerry:~/paperwave/target/debug]$ nix-shell -p libgpiod

[pi@jerry:~/paperwave/target/debug]$ sudo gpioinfo -c gpiochip0
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

Uhhh... we'll probably need better logs from `paperwave` about which GPIO chip and line is "busy" to dive into that, no problem. Lets table that for now and switch back to the issue of the `pi` user not being able to manipulate the devices `paperwave` needs to talk to this thing.

### User permissions for GPIOs and i2c buses

```
[nix-shell:~/paperwave/target/debug]$ ls -la /dev | grep "spi\|gpio\|i2c"
crw-rw----  1 root gpio  254,   0 Nov 16 19:16 gpiochip0
crw-rw----  1 root gpio  254,   1 Nov 16 19:16 gpiochip1
crw-rw----  1 root gpio  237,   0 Nov 16 19:16 gpiomem
crw-rw----  1 root i2c    89,   1 Nov 16 19:16 i2c-1
crw-rw----  1 root i2c    89,  22 Nov 16 19:16 i2c-22
crw-------  1 root root  153,   0 Nov 16 19:16 spidev0.1
```

Looks like we need to be in `gpio`, `i2c`, and then the SPI device is `root:root` so we'll need to take special care of that. Gonna apply this diff turning off i2c0 since it wasn't explicitly called out in the inky python library setup:

```diff
diff --git a/jerry/configuration.nix b/jerry/configuration.nix
index 22e9370..b233188 100644
--- a/jerry/configuration.nix
+++ b/jerry/configuration.nix
@@ -46,6 +46,10 @@
     extraGroups = [
       "wheel"
       "networkmanager"
+
+      # TODO: factor out inky config to its own module
+      "gpio"
+      "i2c"
     ];

     # Can switch to nix-sops if I end up needing to ship more secrets
@@ -62,6 +66,10 @@
     htop
     jq
     git
+
+    # TODO: factor out inky config to its own module
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

Rolling NixOS now, we'll make sure these changes have taken place at runtime:

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

`/dev/i2c-22` is gone now, thats the device that corresponded with `i2c0` in the module options. I have a hunch enabling that extra i2c bus might have been stomping on GPIOs that the `paperwave` needs.

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

> Side note: I finally found a [datasheet](https://files.waveshare.com/wiki/4.2inch%20e-Paper%20Module%20(G)/4.2inch_e-Paper_(G).pdf) for the e-ink controller that my particular model of Inky display is using, its called a JD79668. Got a nice ring to it.

### Custom device tree overlay for SPI devices

Trying to update the display again with `paperwave` I'm still getting the resource busy issue. Reading through the source in `paperwave` I can see we're trying to manipulate 4 different GPIO pins: `gpiochip0` line 8, 22, 27, and 17. These correspond with the docs from Pimoroni on the pinout for the display [here](https://pinout.xyz/pinout/inky_what).

I wasn't getting clear error messages from `paperwave` so I narrowed down the problem by manually manipulating GPIOs with `gpioset`

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

So pin 8 is our problem child, which is supposed to be the SPI0 chip select pin. Whats happening here is the SPI driver the kernel loaded is laying claim to pin 8 as a chip select pin, but `paperwave` wants to handle chip selection manually. `paperwave` is trying to manipulate it as a plain-old GPIO. This has to do with the TV hat device tree overlay we applied...

I'm pretty sure that the [`spi0-0cs-overlay.dts`](https://github.com/raspberrypi/linux/blob/rpi-6.1.y/arch/arm/boot/dts/overlays/spi0-0cs-overlay.dts) checked into the `raspberrypi/linux` repo sets no chip select pins, `*-1cs` sets one chip select pin, and `*-2cs` sets two. Inspecting the TV hat module, we can see both gpio lines 7 and 8 get set as chip select. So all we've got to do is disable that TV hat overlay, and instead apply our own device tree overlay (out of band of the `nixos-hardware` options) which perfectly matches the raspberrypi "upstream" overlay with 0 chip select chips. The kernel will get its hands off that GPIO line and the "Device busy" issue should go away.

I ended up modifying the TV Hat overlay to exclude the chip select chips and the kernel is hands-off the GPIOs that paperwave needs now, nice. Here's what the device tree source I applied ended up looking like:

```dts
/dts-v1/;
/plugin/;

/{
    compatible = \"brcm,bcm2711\";

    // --- Remove all hardware chip-select pins ---
    // We keep only the SPI0 SCLK/MISO/MOSI pins.

    fragment@0 {
        target-path = \"/soc/gpio@7e200000\";
        __overlay__ {
            spi0_pins: spi0_pins {
                brcm,pins = <9 10 11>;      // SPI0 SCLK, MOSI, MISO
                brcm,function = <4>;         // ALT0 for SPI0
            };

            // Do NOT define spi0_cs_pins at all
            // (hardware CS pins remain unused and free)
        };
    };

    fragment@1 {
        target-path = \"/soc/spi@7e204000\";
        __overlay__ {
            pinctrl-names = \"default\";
            pinctrl-0 = <&spi0_pins>;

            /*
            * Use software chip select for both CS0 and CS1
            *
            * Setting each entry to <0> means:
            *   “no GPIO chip-select; let the SPI controller
            *    manage chip-select internally (software CS)”
            *
            * Required format: one entry per chip-select.
            */
            cs-gpios = <0>, <0>;

            status = \"okay\";

            // --- SPI Devices (keeps /dev/spidev0.0 and not /dev/spidev0.1) ---
            spidev0: spidev@0 {
                compatible = \"lwn,bk4\";
                reg = <0>;
                #address-cells = <1>;
                #size-cells = <0>;
                spi-max-frequency = <125000000>;
            };

            // Disable spidev1 (CE1) explicitly
            spidev1: spidev@1 {
                status = \"disabled\";
            };
        };
    };
};
```

### SPI device user permissions

Running this back with the `paperwave` CLI we get a new error around perms:

```
[pi@jerry:~/paperwave/target/debug]$ ./paperwave
Ready to roll...
== Probe Report ==
EEPROM: 400x300 colour=7 pcb_variant=10.0 display_variant=24 (Red/Yellow wHAT (JD79668)) (via /dev/i2c-1)
Display: JD79668 (400x300)

...

Error: IO error: Permission denied (os error 13)
```

which I believe is because the SPI devices are owned by `root`:

```
[pi@jerry:~/paperwave/target/debug]$ ls -ls /dev/ | grep spi
0 crw------- 1 root root  153,   0 Nov 16 22:26 spidev0.0
0 crw------- 1 root root  153,   1 Nov 16 22:26 spidev0.1
```

I think the right way to fix that is to get the SPI devices to be owned by some other group and then add the `pi` user to that group. For now, we hit the `sudo` button. We get further!

```
Creating the display... the display spec we have is: Some(Jd79668 { width: 400, height: 300 })
Error: Unsupported resolution 400x300
```

Ok hell ya, this is just a failure in application code (the `paperwave` library doesn't support my specific model of e-ink display so we'll have to go wrench on it) but I think all the hardware might be doing the right things now. We'll go back to that `pi` user perms on SPI devices.

We'll cook up a `udev` rule to apply here, first inspecting some attributes of this device to match on:

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

```nix
users.groups = { spi = { }; };
users.users.pi.extraGroups = [ "spi" ];
services.udev.extraRules = ''
  # Add the spidev0.0 device to a group called spi (by default its root) so that our user
  # can be added to the group and make use of the device without elevated perms.
  SUBSYSTEM=="spidev", KERNEL=="spidev0.0", GROUP="spi", MODE="0660"
'';
```

I'm dumping all of this in the `configuration.nix` for the device for now, but ultimately I'd like to factor out the complexity of the inky-specific configuration into its own module and hide it behind a `mkEnableOption`, but we'll cross that bridge after we've got some ink on the display.

"Say the line Bart!" 

"`nixos-rebuild boot --flake .#`"

Nice, now we've got the SPI device owned by the `spi` group, and our `pi` user is a card-carrying member of it:

```
[pi@jerry:~]$ ll /dev/ | grep spi
crw-rw---- 1 root spi   153,   0 Nov 16 23:00 spidev0.0

[pi@jerry:~/pi-nixos]$ groups pi
pi : users wheel networkmanager spi i2c gpio
```

I'll confirm we're making it past the permission denied error in `paperwave`

```
Creating the display... the display spec we have is: Some(Jd79668 { width: 400, height: 300 })
Error: Unsupported resolution 400x300
```

Money... now its time to just hack on `paperwave` to support my 400x300 e-ink display with a JD79668 controller.

### Many hours later

I quickly resolved the "unsupported resolution" issue, but upon further investigation I discovered that the two other e-ink display controllers supported by `paperwave` are not even made by the same manufacturer as mine. They have different pinouts and different command interfaces. The only things these devices have in common is that they all use a few GPIOs, i2c for the EEPROM, and SPI for actually driving the display. Basically 0% of this interface is working except for the EEPROM read that the CLI already showed us. I'm going to be diving into the datasheet and the python library to add support for my display but I'm afraid I might be writing a userspace driver for this thing basically from scratch.

### A full day later

I had to pretty heavily slice and dice into `paperwave` to have any success, including a rewrite of the SPI interface code. I also switched the GPIO library from `gpio-cdev` to `gpiocdev` (mind the lack of a dash) so that I could express the pull-up bias on the GPIO busy pin that allows the display to express that its working and not ready to receive new commands.

I've got the display responding, but test images are managled so there's still bugs in `paperwave`, or rather bugs in my additions for JD79668 support.

TODO: put an image in here

### Only a few minutes later

I cracked it. My display is a 4-color display, and the way we encode an image with arbitrary colors in it is by "indexing" or "palletizing" it. So we take the original, and for each RGB pixel value we figure out which color in our 4-color pallete is closest, and we literally store the index of that color for the image. In the case of the JD79668 those correspondances look like this:

```rust
const PALETTE: [[u8; 3]; 4] = [
    [0, 0, 0],       // 0: Black
    [255, 255, 255], // 1: White
    [255, 255, 0],   // 2: Yellow
    [255, 0, 0]      // 3: Red
];
```

After that palletizing, we'll have an image which is 1-byte per pixel where the pixel value is 0, 1, 2, or 3.

The other displays supported in `paperwave` took that palletized image and bit-packed it with 4-bits per pixel, and then serialized it to send it over SPI. Those other displays support 7-colors though, my display can be more aggressive with the bit-packing since we only need to express values 0-3.

```
0 -> b00
1 -> b01
2 -> b10
3 -> b11
```

We only need 2-bits per pixel. [Here's](https://github.com/pimoroni/inky/blob/d03b518928988779625b246d4cc558ea523a2944/inky/inky_jd79668.py#L271C1-L272C1) where that bit-arithmetic was happening in the python library provided by Pimoroni, it looks like this and it took me a minute to realize what was happening:

```python
buf = region.flatten()
buf = ((buf[::4] & 0x03) << 6) | ((buf[1::4] & 0x03) << 4) | ((buf[2::4] & 0x03) << 2) | (buf[3::4] & 0x03)
```

I confirmed the bit-packing convention in the manual for the JD79668 and sure enough its written there in plain English.

> 4-bits (half of a byte) is called a "nibble", but the internet doesn't seem to agree on what half of a nibble is. I've seen "nibblet", "crumb", and "taste".

After reflecting that change in my rust implementation we're off to the races. I started by just implementing palletization into black and white because the [`image`](https://github.com/image-rs/image) crate supports a simple color mapping called `BiLevel` which implements their `ColorMap` trait. I'll end up having to implement a type which implements `ColorMap` for my display's pallete to unlock the rest of the colors. I'd also like to add some dithering capability to make arbitrary graphics present better.

TODO: photos of things working

## Bonus

Here's some usefulness I wasn't privy to before embarking on this jouney, mostly to do with generating test images to display.

ImageMagick is so slick, this is taking a square SVG with an alpha channel, resizing it to the native resolution of my display whilst maintaining the original aspect ratio by padding and keeping the original centered, converting the colorspace to black and white, and re-encoding as a PNG:

```
convert nixos-logo.svg \
    -resize 400x300 \
    -gravity center \
    -extent 400x300 \
    -monochrome \
    test.png
```

TODO: Add the original and converted version
