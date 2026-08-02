{ config, pkgs, ... }:

{
  # Home Manager ユーザー情報
  home.username = "renkon";
  home.homeDirectory = "/home/renkon";

  # Home Manager の設定バージョン（初回セットアップ時のバージョンを保持）
  home.stateVersion = "24.05";

  # ---------------------------------------------------------------------------
  # 1. 既存ドットファイルの配置 (そのままシンボリックリンク展開)
  # ---------------------------------------------------------------------------
  home.file = {
    ".zshrc".source = ./home/.zshrc;
    ".bashrc".source = ./home/.bashrc;
    ".aliases".source = ./home/.aliases;
    ".gitconfig".source = ./home/.gitconfig;
  };

  # ~/.config/ 配下のファイル
  xdg.configFile = {
    "starship.toml".source = ./config/starship.toml;
  };

  # ---------------------------------------------------------------------------
  # 2. PATH や環境変数の設定
  # ---------------------------------------------------------------------------
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/bin"
  ];

  # ---------------------------------------------------------------------------
  # 3. Nix で管理するパッケージ (段階的移行)
  # 必要な CLI ツールをここに追加していきます
  # ---------------------------------------------------------------------------
  home.packages = with pkgs; [
    # 例: 段階的に Nix 管理へ移行したい定番ツール
    # ripgrep
    # fd
    # jq
    # starship
    # zoxide
  ];

  # Home Manager 自身の有効化
  programs.home-manager.enable = true;
}
