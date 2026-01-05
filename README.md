# serenity

NixOS configurations for embedded Linux projects. Currently I'm only supporting the RPi 4 Model B, targeting aarch64.

### Install

There's notes on bootstrapping this NixOS configuration from the mainline NixOS aarch64 SD card installer in the `notes/` directory. Below, I'll walk myself through building and booting from an SD card installer built from these `nixosConfigurations`. I have a generic "`base`" configuration with none of the RPi peripherals turned on, but there's a user with a default password, NetworkManager, OpenSSH, a static IP configured on the ethernet port, and other conveniences.

TODO

### Tailscale

I use tailscale for remote access. I shipped a module which automates login (`tailscale up`) using tailscale "auth keys". They expire every 90 days. To make a new one you can head to the tailscale admin console -> Settings -> Keys, and add a new auth key. I configure these auth keys to be "reusable" so I can ship them to more than one host, but thats innately less secure. I store the auth keys themselves in 1password and then encrypt them, and deploy them using `agenix`. See below for details on secrets management.

Tailscale SSH is enabled by default if auto connect is enabled by providing an auth key via `agenix`.

> Note: One of the advantages that tailscale SSH offers is the ability to authenticate without having to ship around SSH keys. That advantage is defeated by the use of agenix since the SSH private key imperatively delivered to the the running system is used to decrypt the age files. In the future I can tackle a way to do secrets management without shipping around SSH keys and get this advantage back.

Auth keys must be manually rotated every 90 days to keep us autoconnected to the tailscale network.

### Secrets management

I'm using [`agenix`](https://github.com/ryantm/agenix) for declarative secrets management. The TLDR is that the `agenix`
module will help us ship `.age` files prepared via the `agenix-cli` (encrypted with an SSH keypair) to the filesystem
of an activated system. The private key of that keypair must be made available to the running system imperatively, i.e.
literally `scp`'ed by hand.

#### Preparing an age file

> Note: the `agenix-cli` package in 25.05 upstream nixpkgs is an old and seemingly non-functional version, make sure
> you're using the CLI provided by the `agenix` flake, thats what is shipped in this flake's `devShell`.

You'll need a `secrets.nix` file listing the public keys for which the keypair will be allowed to decrypt the agefile.
You can have multiple allowed keypairs for a given agefile. That'll look like something like:

```nix
let
  mykey = "ssh-ed25519 SOME_PUBLIC_KEY email@email.com";
in
{
  "mysecret.age".publicKeys = [ mykey ];
}
```

Now you can create the agefile, by default the CLI looks for this rules file in `./secrets.nix`. The `agenix` CLI will
default to using `~/.ssh/id_ed25519` for your identity but you can override it with `-i`:

```
cd secrets
agenix -e mysecret.age
```

Paste in the secret in your `$EDITOR` and save it off.

#### Deploy a secret

Then go add the secret to a NixOS configuration via the `age` options provided by the `agenix` module:

```nix
{
  age.secrets.secret1.file = ../secrets/secret1.age;
}
```

When the age.secrets attribute set contains a secret, the agenix NixOS module will later automatically decrypt and
mount that secret under the default path `/run/agenix/secret1`. Here the `secret1.age` file becomes part of your NixOS
deployment, i.e. moves into the Nix store (but the secret is not stored in plaintext in the Nix store).

You can reference that path with `config.age.secrets.secret1.path` for whatever piece of configuration is meant to
consume the secret.
