# pi-nixos

NixOS configurations for the Raspberry Pi SBC. Currently I'm only supporting the RPi 4 Model B targeting aarch64.

### Install

There's notes on bootstrapping this NixOS configuration from the mainline NixOS aarch64 SD card installer in the `notes/` directory. Below, I'll walk myself through building and booting from an SD card installer built from these `nixosConfigurations`. I have a generic "`base`" configuration with none of the RPi peripherals turned on, but there's a user with a default password, NetworkManager, OpenSSH, a static IP configured on the ethernet port, and other conveniences.

TODO
