{ config, lib, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    package = pkgs.zsh;
    enableCompletion = true;

    autosuggestion = {
      enable = true;
      strategy = [
        "history"
        "completion"
      ];
    };

    fastSyntaxHighlighting.enable = true;

    history = {
      path = "${config.home.homeDirectory}/.zsh_history";
      size = 10000;
      save = 20000;
      share = true;
      ignoreAllDups = true;
      ignoreSpace = true;
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "";
    };

    shellAliases = {
      gemini = "agy";
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
    };

    initContent = lib.mkAfter (builtins.readFile ../config/zsh/init.zsh);
  };
}
