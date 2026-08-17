{
  description = "Home Manager configuration of renkon";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      homeConfiguration = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
      };
    in
    {
      homeConfigurations.renkon = homeConfiguration;
      checks.${system}.home-manager = homeConfiguration.activationPackage;
      packages.${system}.home-manager = home-manager.packages.${system}.home-manager;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          deadnix
          git
          jq
          ripgrep
          shellcheck
          starship
          statix
          zsh
        ];
      };
    };
}
