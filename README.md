## Why
Because using Nix declaratively with the reproducible guarantees of Flakes is _the_ way to use it effectively, 
in your authors humble opinion. But some users don't even know where to begin.

## Where
The latest stable Nix binary can be installed from the `2.x-maintenance` branches of [github:nixos/nix][nix], 
and the best chance of binary cache hits on nixpkgs is to track the either `nixpkgs-*` or `nixos-*` branches.

## Example for Various Platforms
The links in this section will take you to the corresponding module option docs for that system, so you can
extend these examples right away.

Keep in mind that these options are also available locally:
* NixOS & Nix Darwin: `man configuration.nix`
* Home Manager: `man home-configuration.nix`

The [flake.nix](./flake.nix) in this repo contains identical configuration outputs for 
[NixOS][nixos],  [Home Manager][home-manager], and  [Nix Darwin][nix-darwin]
to demonstrate setting up Nix with some minimal sane defaults.

Additionally, for the Darwin and NixOS config, we demonstrate how to bring home-manager into scope properly.

Notes:
* For easily defining the same package for multiple architectures, checkout [flake-utils][utils].
* Simply run `nix flake lock --update-input <input-name>` to check for an update for the various inputs; Nix itself for example.

## Avoid Imperative Commands, Use `nix shell` Instead!

Tracking your entire system reproducibly is incredible beneficial, but that guarantee is broken the second we start calling Nix to install
packages imperatively into our user profiles via `nix profile install` and the like, but sometimes we only need a given tool on an `ad hoc` basis
and adding it to our configuration files is overkill.

The unique power of `nix shell` is your best friend, and combined with the new Flakes interface can reliably target Nix expressions down to the VCS revision:

In this example, we use the pinned version if nixpkgs via the `nixos` flake input we pinned above. 
This way, Nix doesn't have to pull a copy from the network and evaluate it each time we want to call a new shell:
```bash
# spawn a fresh shell instance with the `wormhole` command in scope
$ nix shell nixos/arbitrary-git-ref#magic-wormhole   

# send a file to a friend
$ wormhole send ./some-file

# simply exit the shell and `wormhole` is no longer available
$ exit
```

[nix]: https://github.com/nixos/nix
[utils]: https://github.com/numtide/flake-utils
[nixos]: https://nixos.org/manual/nixos/unstable/options
[nix-darwin]: https://lnl7.github.io/nix-darwin/manual/index.html#sec-options
[home-manager]: https://nix-community.github.io/home-manager/options.html
