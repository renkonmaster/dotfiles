{ config, lib, pkgs, ... }:

let
  mise = config.programs.mise;
in
{
  programs.mise = {
    enable = true;
    enableZshIntegration = true;

    globalConfig.tools = {
      direnv = "latest";
      fzf = "latest";
      go = "latest";
      node = "lts";
      rust = "latest";
      starship = "latest";
      uv = "latest";
      zoxide = "latest";
    };
  };

  # Home Manager writes the global configuration first, then mise installs any
  # missing versions. Running this on every switch is safe because mise skips
  # versions that are already installed.
  home.activation.installMiseTools = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    (
      export HOME=${lib.escapeShellArg config.home.homeDirectory}
      export XDG_CACHE_HOME=${lib.escapeShellArg config.xdg.cacheHome}
      export XDG_CONFIG_HOME=${lib.escapeShellArg config.xdg.configHome}
      export XDG_DATA_HOME=${lib.escapeShellArg config.xdg.dataHome}
      export XDG_STATE_HOME=${lib.escapeShellArg config.xdg.stateHome}

      cd ${pkgs.emptyDirectory}
      verboseEcho "Installing tools declared in the Home Manager mise configuration"
      run ${lib.getExe mise.package} install --yes
    )
  '';
}
