{ config, lib, pkgs, ... }:

{
  imports = [ ];

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
  ];

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

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
}

