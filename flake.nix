{
  # don't add any `follows` statements on `nix` to avoid a cache miss
  inputs.nix.url = "github:nixos/nix/2.9-maintenance";

  # both of these branches are well cached; `unstable` less so
  inputs.nixos.url = "github:nixos/nixpkgs/nixos-22.05";
  inputs.unstable.url = "github:nixos/nipkgs/nixpkgs-unstable";

  # home-manager is super useful even for those outside of NixOS
  inputs.home-manager.url = "github:nix-community/home-manager";

  # useful for Mac users
  inputs.nix-darwin.url = "github:LnL7/nix-darwin";

  outputs =
    # bring all inputs defined above into scope:
    inputs: with inputs; let
      # nice to have a copy of the nixpkgs library around
      inherit (unstable) lib;

      # define the system architecture explicitly
      system = "x86_64-linux";

      # username for home-manager
      username = "a-user";
    in {
      # --- NixOS ----------------
      nixosConfigurations.aSystem = lib.nixosSystem {
        inherit system;

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
