# Declarative Flake Best Practices

## Why
Because using Nix declaratively with the reproducible guarantees of Flakes is _the_ way to use it effectively, 
in your authors humble opinion.

## Where
The latest stable Nix binary can be installed from the `2.x-maintenance` branches of [github:nixos/nix][nix], 
and the best chance of binary cache hits on nixpkgs is to track the either `nixpkgs-*` or `nixos-*` branches.

## Example for Various Platforms
The following example contains identical configuration outputs for 
[NixOS][nixos],  [Home Manager][home-manager], and  [Nix Darwin][nix-darwin]
to demonstrate setting up Nix with some minimal sane defaults.

Additional, for the Darwin and NixOS config, we demonstrate how to bring home-manager into scope properly:
```nix
# flake.nix
{
  # don't add any `follows` statements on `nix` to avoid a cache miss
  inputs.nix.url = "github:nixos/nix/2.9-maintenance"

  # both of these branches are well cached; `unstable` less so
  inputs.nixos.url = "github:nixos/nixpkgs/nixos-22.05";
  inputs.unstable.url = "github:nixos/nipkgs/nixpkgs-unstable";
  
  # home-manager is super useful even for those outside of NixOS
  inputs.home-manager.url = "github:nix-community/home-manager";
  
  # useful for Mac users
  inputs.nix-darwin.url = "github:LnL7/nix-darwin";
  
  outputs = 
    # bring all inputs defined above into scope:
    inputs: with inputs; 
    let 
      # nice to have a copy of the nixpkgs library around
      inherit (unstable) lib;

      # define the system architecture explicitly
      system = "x86_64-linux";
      
      # username for home-manager
      username = "a-user";

    in {
      # --- NixOS ----------------
      nixosConfigurations.aSystem = lib.nixosSystem {
        inherit ${system}
        
        modules = [
          # import home-manager
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }

          # can exist in a seperate file.nix file and imported here with a path: ./file.nix
          ({pkgs, ...}: { 

            # install Nix from the `nix` flake input
            nix.package = nix.packages.${pkgs.system}.nix; 

            # add all inputs as cached registry entries for cached evaluations and quick `nix search`, etc
            nix.registry = builtins.mapAttrs (_: flake: {inherit flake;}) inputs;

            # set the `NIX_PATH` so legacy nix commands use the same nixpkgs as the new commands
            nix.nixPath = [
              "nixpkgs=${inputs.nixos}"
              "home-manager=${inputs.home-manager}"
            ];
          })
        ];
      };
      
      # --- Home Manager ---------
      homeConfigurations."${username}@aSystem" = home-manager.lib.homeManagerConfiguration {
        inherit username system;

        # put this in a file and call `import file.nix` instead:
        configuration = {pkgs, ...}: {
          # many `nix` options are identical to NixOS...
          nix.package = nix.packages.${pkgs.system}.nix; 
          nix.registry = builtins.mapAttrs (_: flake: {inherit flake;}) inputs;
          
          # some are not
          nix.settings.nix-path = [
            "nixpkgs=${inputs.unstable}"
            "home-manager=${inputs.home-manager}"
          ];
        };
      };      

      # --- Mac OSX --------------

      darwinConfigurations."aMacbook" = nix-darwin.lib.darwinSystem {
        system = "x86_64-darwin";
        modules = [ 
          # setup home-manager
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }

          # can instead be a ./path.nix just like NixOS modules
          ({pkgs, ...}: {
            nix.package = nix.packages.${pkgs.system}.nix; 
            nix.registry = builtins.mapAttrs (_: flake: {inherit flake;}) inputs;
            nix.settings.nix-path = [
              "nixpkgs=${inputs.unstable}"
              "home-manager=${inputs.home-manager}"
            ];
          }) 
        ];
      };
    }; 
    
    # set `nix.conf` options right here and ensure they are included on everything exported by this flake
    # this is a great way to ensure your packages are always pulled from a substituter when available.
    nixConfig = {
      extra-substituters = [
        "https://nix-community.cachix.org"
      ];      

      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];    
    };
}
```

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
[darwin]: https://lnl7.github.io/nix-darwin/manual/index.html#sec-options
[home-manager]: https://nix-community.github.io/home-manager/options.html
