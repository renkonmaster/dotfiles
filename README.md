# dotfiles

Zsh, Bash, Git などの個人設定ファイル。Nix (Home Manager) で管理。

## 構成

- `home/`: ホームディレクトリ (`~/`) に配置するファイル
- `config/`: `~/.config/` に配置するファイル
- `flake.nix`, `home.nix`: Home Manager の設定

## セットアップ

### 1. Nix のインストール (未導入の場合)

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### 2. Home Manager の適用

```bash
git clone https://github.com/renkonmaster/dotfiles.git ~/dotfiles
cd ~/dotfiles
nix run github:nix-community/home-manager -- switch --flake .#renkon
```

## 使い方

設定変更後の反映:

```bash
home-manager switch --flake .
```

- **設定ファイルの変更**: `home/` や `config/` 以下のファイルを編集して上記の反映コマンドを実行
- **パッケージ追加**: `home.nix` の `home.packages` に追記して上記の反映コマンドを実行

## マシン固有設定

個別の環境変数や認証情報などは git 管理外の以下に記述する。

- `~/.gitconfig.local`
- `~/.zshrc.local`
- `~/.bashrc.local`
