{ config, lib, pkgs, ... }:
let
  cfg = config.inky;
in
{
  imports = [ ];

  options.inky = {
    enable = lib.mkEnableOption "inky e-ink displays";
  };

  config = lib.mkIf cfg.enable {
    users.users.pi = {
      extraGroups = [
        "gpio"
        "i2c"
        "spi"
      ];
    };

    users.groups = { spi = { }; };
    services.udev.extraRules = ''
      # Add the spidev0.0 device to a group called spi (by default its root) so that our user
      # can be added to the group and make use of the device without elevated perms.
      SUBSYSTEM=="spidev", KERNEL=="spidev0.0", GROUP="spi", MODE="0660"
    '';

    environment.systemPackages = with pkgs; [
      i2c-tools
      libgpiod
    ];

    hardware.raspberry-pi."4" = {
      gpio.enable = true;

      i2c1 = {
        enable = true;

        # Actually unclear what this should be but I have not had issues reading
        # from the Inky EEPROM via i2c so far.
        frequency = null;
      };
    };

    # For the inky e-ink displays we need SPI comms with zero chip select pins enabled, our userspace library
    # will handle chip selection for us. We should end up with SPI drivers show up in lsmod, and a SPI character
    # device in /dev, but gpiochip0 lines 7 and 8 should not be claimed by a kernel driver.
    # Here's the upstream overlay which achieves this, we're gonna drop it in verbatim, and only try 
    # `hardware.raspberry-pi."4".apply-overlays-dtmerge.enable = true;` if we need to.
    # 
    # https://github.com/raspberrypi/linux/blob/rpi-6.1.y/arch/arm/boot/dts/overlays/spi0-0cs-overlay.dts
    #
    # Other configurations that the TV hat option applied...
    # 
    # hardware.raspberry-pi."4".apply-overlays-dtmerge.enable = true;
    # hardware.deviceTree.filter = "*-rpi-4-*.dtb";
    #
    # This was adapted from: https://github.com/NixOS/nixos-hardware/blob/master/raspberry-pi/4/tv-hat.nix
    hardware.deviceTree.overlays = [
      {
        name = "spi0-0cs.dtbo";
        dtsText = "
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
      };";
      }
    ];
  };
}
