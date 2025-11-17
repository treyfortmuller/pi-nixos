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

    tv-hat.enable = true;
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?
}

