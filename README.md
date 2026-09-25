# dotfiles

Ubuntu / WSL2 の環境構築を mise にまとめた dotfiles です。メインシェルは zsh。
Nix / Home Manager は不要です。mise の `bootstrap` と `dotfiles` に対応した
バージョンを使います（設定は v2026.9.13 の公式ドキュメントを基準に作成）。

**この移行版は未検証・未適用です。** テスト、構文チェック、インストール、
シェル起動確認はまだ行っていません。CI も当面は手動実行のみです。

## 管理するもの

| 対象 | 設定 |
| --- | --- |
| zsh・Git・ビルド依存（mise から apt を実行） | `mise.toml` の `bootstrap.packages` |
| Oh My Zsh・autosuggestions・fast-syntax-highlighting | `mise.toml` の `bootstrap.repos` |
| 設定ファイルのシンボリックリンク | `mise.toml` の `dotfiles` |
| Node.js・Go・Rust・uv・Starship・eza・fzf・zoxide・direnv | `config/mise/config.toml` |
| zsh の履歴・補完・プラグイン | `home/.zshrc` |
| zsh の PATH・ログイン設定 | `home/.zshenv`、`home/.zprofile` |
| CLI の起動処理・eza / clipboard alias | `config/zsh/init.zsh` |
| Git・Starship | `home/.gitconfig`、`config/starship.toml` |

Python 環境と Python 製 CLI は引き続き uv を使います。Windows 側の VS Code と
GUI アプリは Windows 側で管理します。`home/.bashrc` は任意利用の互換設定として
残しますが、セットアップでは配置しません。

## セットアップ（後で適用する時）

先に [mise の公式手順](https://mise.jdx.dev/getting-started.html) で、Nix に依存しない
mise 本体をインストールし、PATH に追加します。初回の clone には Git が必要です。
既存環境では先に [移行手順](docs/mise-migration.md) に従ってバックアップしてください。

リポジトリ直下で実行します。

```zsh
mise trust
mise run setup
```

`setup` は OS パッケージ、シェルプラグイン、設定リンク、CLI の順に導入します。
apt の操作には必要に応じて sudo が使われます。ログインシェルの変更は自動では
行いません。必要なら適用後に `chsh -s /usr/bin/zsh` を別途実行してください。

配置先は標準の `~/.config`、プラグインは `~/.local/share/dotfiles` です。
`XDG_CONFIG_HOME`、`MISE_CONFIG_DIR`、`MISE_GLOBAL_CONFIG_FILE`、`ZDOTDIR` を
変更している環境では、先に `mise.toml` の配置先とシェル設定を合わせてください。
リンクの参照先になるので、このチェックアウトは適用後も残します。

## 設定の更新

CLI の追加・バージョン変更は `config/mise/config.toml` を編集し、リポジトリ直下で
`mise install` を実行します。グローバル設定もこのファイルへのリンクなので、
プロジェクト外でも同じツールを使えます。プロジェクト固有のバージョンは各
プロジェクトの `mise.toml` で上書きできます。

プラグインは `mise bootstrap repos apply` で導入します。Oh My Zsh は初回 clone
時の版を使い、通常の apply では更新しません。明示的な更新は
`mise bootstrap repos update` で行います。タグを指定したプラグインはそのタグを
維持するため、更新したい場合は `ref` を編集してください。

CLI は従来の `latest` / `lts` 指定を引き継いでいます。Nix のロックと同等の
完全なバージョン固定ではありません。今回はバージョン解決や lock 生成も未実行です。

機密情報や端末固有設定は `~/.gitconfig.local`、`~/.zshrc.local` に置きます。
必要に応じて `~/.zshenv.local`、`~/.zprofile.local`、`~/.zsh_aliases` も読み込みます。
SSH 署名キー、Git のユーザー情報、既存の traP 用 Git include は端末側で保持します。

## 検証（後で明示的に実行）

```zsh
mise run check
```

zsh と Git は OS 側に必要です。検証用 CLI は check タスクで mise が導入します。
このタスクは構文チェック、隔離した HOME での zsh 起動、共有設定などを確認します。
`setup` からは呼びません。実際の mise bootstrap、apt、プラグインのダウンロードまで
検証するものではないため、初回適用時にはそれらの確認も別途必要です。

## VS Code

Windows 側の PowerShell から拡張機能を適用します。

```powershell
Get-Content .\vscode\Laptop-win\extensions.txt |
  ForEach-Object { code --install-extension $_ }
```

設定・キーバインド・スニペットは `vscode/Laptop-win/` にあります。

## mise の仕様参照

- [Bootstrap](https://mise.jdx.dev/bootstrap.html)
- [Dotfiles](https://mise.jdx.dev/dotfiles.html)
- [Git repositories](https://mise.jdx.dev/bootstrap/repos.html)
- [apt packages](https://mise.jdx.dev/bootstrap/packages/apt.html)
