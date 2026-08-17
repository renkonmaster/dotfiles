# dotfiles

WSL2 上の Zsh と共有設定を、Nix Flake と Home Manager で再現するための
リポジトリです。言語ランタイムや日常的な CLI の導入方法は、これまでどおり
mise / uv を使います。

## 管理方針

- Home Manager: Zsh 本体、Zsh 設定、Git 設定、Starship 設定ファイル
- mise: Node.js、Go、Starship など現在 mise で管理しているツール
- uv: Python プロジェクトと Python 製ツール
- Windows 側: VS Code 本体と GUI アプリ

Home Manager の設定を編集しても、`home-manager switch` を実行するまでは
現在のホームディレクトリへ反映されません。このリポジトリの検証コマンドも、
ホームディレクトリの設定やログインシェルを変更しません。

## Nix と Home Manager の役割

- `flake.nix`: 構成の入口と、検証に使う一時的な開発環境
- `flake.lock`: nixpkgs と Home Manager の版を固定するファイル
- `home.nix`: ユーザー名、ホームディレクトリ、各モジュールの読み込み
- `modules/`: Zsh・Git・共有 dotfiles の宣言
- `config/zsh/init.zsh`: mise など外部ツールを、存在確認後に初期化する処理

`nix develop` は検証ツールを一時的な PATH に置くだけです。`nix build` は
Nix store に構成を組み立てるだけで、`~/.zshrc` などを置き換えません。
実際にホームディレクトリへ反映する操作は `home-manager switch` です。

## 検証

```zsh
nix develop --command ./tests/check.sh
nix flake check
nix build --no-link .#homeConfigurations.renkon.activationPackage
```

最後のコマンドは Home Manager の activation package をビルドしますが、
activation script を実行しないため、現在の PC には適用されません。

## 設定を変更する

- Zsh の履歴・補完・プラグイン・alias: `modules/zsh.nix`
- mise、Starship、fzf などの起動処理: `config/zsh/init.zsh`
- Git 設定: `home/.gitconfig` と `modules/git.nix`
- Starship の表示: `config/starship.toml`
- その他の共有ファイル: `modules/dotfiles.nix`

認証情報や PC 固有設定はコミットせず、`~/.gitconfig.local` または
`~/.zshrc.local` に置きます。Home Manager が生成する `.zshrc` は最後に
`~/.zshrc.local` を読み込みます。

Home Manager は `.bashrc` を管理しません。移行完了までは互換用ファイルが
残りますが、Zsh の設定から Bash を読み込むことはありません。

## ツールを追加する

mise が対応するツールや言語ランタイムは、これまでどおり次の形で追加します。

```zsh
mise use --global <tool>@<version>
mise install
```

Python 製 CLI は `uv tool install <package>`、プロジェクトごとの Python 依存は
各プロジェクトの `uv` 設定で管理します。Home Manager へ追加するのは Zsh
本体や dotfiles 側の依存だけで、mise 管理ツールを重複して追加しません。

## VS Code

Windows 側の VS Code へ拡張機能一覧を適用する場合は、リポジトリ直下で
PowerShell から実行します。

```powershell
Get-Content .\vscode\Laptop-win\extensions.txt |
  ForEach-Object { code --install-extension $_ }
```

設定、キーバインド、スニペットは `vscode/Laptop-win/` に分割しています。

## 初回移行

初回適用は既存リンクのバックアップと復旧経路を確認してから行います。
手順は [Home Manager 移行手順](docs/home-manager-migration.md) を参照してください。
