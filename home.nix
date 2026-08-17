_:

{
  imports = [
    ./modules/dotfiles.nix
    ./modules/git.nix
    ./modules/mise.nix
    ./modules/zsh.nix
  ];

  home = {
    username = "renkon";
    homeDirectory = "/home/renkon";
    stateVersion = "24.05";

    sessionPath = [
      "$HOME/.cargo/bin"
      "$HOME/.local/bin"
      "$HOME/bin"
    ];
  };

  programs.home-manager.enable = true;
}
