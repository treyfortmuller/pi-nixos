# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  swapDevices = [
    {
      device = "/swapfile";
      size = 4096; # 4 GiB
    }
  ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;

  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  networking = {
    hostName = "jerry";
    networkmanager.enable = true;
    usePredictableInterfaceNames = true;

    # Static IP on the physical ethernet port
    interfaces.end0.ipv4.addresses = [{
      address = "192.168.10.7";
      prefixLength = 24;
    }];
  };

  # If null, the timezone will default to UTC and can be set imperatively
  # using timedatectl.
  time.timeZone = null;

  users.mutableUsers = true; # So we can change passwords after install
  users.users.pi = {
    isNormalUser = true;
    extraGroups = [ 
      "wheel"
      "networkmanager"

      # TODO: split this out into wHAT configuration for the inky
      "gpio"
      "i2c"
      "spi"
    ]; 

    # Can switch to nix-sops if I end up needing to ship more secrets
    initialHashedPassword = "$y$j9T$e/ww3cpvzIyWV2oz4VOd6/$6sMcui1lQ7tN7ZnjkJWySfaDbWAgs9V0tSuBTaViJu3";
  };

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    vim
    wget
    tty-clock
    tree
    tmux
    htop
    jq
    git

    # TODO: inky things, split these out
    i2c-tools
    libgpiod
  ];

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    trusted-users = [
      "root"
      "pi"
      "@wheel"
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # RPi specifics provided by nixos-hardware:
  # 
  # nix-repl> nixosConfigurations.jerry.options.hardware.raspberry-pi.\"4\".
  # hardware.raspberry-pi."4".apply-overlays-dtmerge
  # hardware.raspberry-pi."4".audio
  # hardware.raspberry-pi."4".backlight
  # hardware.raspberry-pi."4".bluetooth
  # hardware.raspberry-pi."4".digi-amp-plus
  # hardware.raspberry-pi."4".dwc2
  # hardware.raspberry-pi."4".fkms-3d
  # hardware.raspberry-pi."4".gpio
  # hardware.raspberry-pi."4".i2c0
  # hardware.raspberry-pi."4".i2c1
  # hardware.raspberry-pi."4".leds
  # hardware.raspberry-pi."4".poe-hat
  # hardware.raspberry-pi."4".poe-plus-hat
  # hardware.raspberry-pi."4".pwm0
  # hardware.raspberry-pi."4".tc358743
  # hardware.raspberry-pi."4".touch-ft5406
  # hardware.raspberry-pi."4".tv-hat
  # hardware.raspberry-pi."4".xhci
  hardware.raspberry-pi."4" = {
    gpio.enable = true;

    i2c1 = {
      enable = true;
      frequency = null; # TODO: what should this be?
    };
  };

  # For the inky e-ink displays we need SPI comms with zero chip select pins enabled, our userspace library
  # will handle chip selection for us. We should end up with SPI drivers show up in lsmod, and a SPI character
  # device in /dev, but gpiochip0 lines 7 and 8 should not be claimed by a kernel driver.
  # Here's the upstream overlay which achieves this, we're gonna drop it in verbatim, and only try 
  # `hardware.raspberry-pi."4".apply-overlays-dtmerge.enable = true;` if we need to.
  # 
  # https://github.com/raspberrypi/linux/blob/rpi-6.1.y/arch/arm/boot/dts/overlays/spi0-0cs-overlay.dts

  # Other configurations that the TV hat option applied...
  # 
  # hardware.raspberry-pi."4".apply-overlays-dtmerge.enable = true;
  # hardware.deviceTree.filter = "*-rpi-4-*.dtb";

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


  # TODO (tff): this is inky specific
  users.groups = { spi = { }; };
  services.udev.extraRules = ''
    # Add the spidev0.0 device to a group called spi (by default its root) so that our user
    # can be added to the group and make use of the device without elevated perms.
    SUBSYSTEM=="spidev", KERNEL=="spidev0.0", GROUP="spi", MODE="0660"
  '';

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?
}

