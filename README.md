# dotfiles

Bash, Zsh, Git 等の環境設定を管理するリポジトリ。

## 構成と設計方針

- **シェル構成**: Zsh をメインシェル、Bash をサブシェルとして運用。両者の設定ポリシーを統一。
- **設定の分離**: メールアドレスやトークン、マシン固有設定は `~/*.local` に切り出し、本リポジトリでは管理しない。
- **エイリアス**: 共通エイリアスは `.aliases` に集約。

## ファイル構成

- `.zshrc`: Zsh 用設定
- `.bashrc`: Bash 用設定
- `.aliases`: Zsh / Bash 共通エイリアス
- `.gitconfig`: Git 共通設定（`~/.gitconfig.local` をインクルード）
- `.config/starship.toml`: Starship プロンプトテーマ設定

## セットアップ手順

ホームディレクトリへシンボリックリンクを作成する。
循環参照を防ぐため、リンク先は絶対パス（または `~`）で指定すること。

```bash
ln -sf ~/dotfiles/.bashrc ~/.bashrc
ln -sf ~/dotfiles/.zshrc ~/.zshrc
ln -sf ~/dotfiles/.aliases ~/.aliases
ln -sf ~/dotfiles/.gitconfig ~/.gitconfig
mkdir -p ~/.config
ln -sf ~/dotfiles/.config/starship.toml ~/.config/starship.toml
```

## セットアップ後の作業

### 1. Git ユーザー情報の設定
`~/.gitconfig.local` を作成し、個人情報を記述する。

```gitconfig
[user]
    name = <name>
    email = <email>
```

### 2. マシン固有設定
個別の環境変数や認証トークンは以下に記述する。
- `~/.zshrc.local` (Zsh 用)
- `~/.bashrc.local` (Bash 用)
