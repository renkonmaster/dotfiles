# dotfiles

Ubuntu / WSL2 向けの、zsh を主に使う dotfiles です。
CLI は mise、Python 環境と Python 製 CLI は uv で管理します。
Nix / Home Manager は不要です。mise 2026.6.1 の通常のタスク機能を使います。

## 初回セットアップ

現時点では `mise run setup` だけで新しい端末の準備がすべて完了するわけでは
ありません。OS パッケージの導入と、表示に使うフォントの導入・選択は自動化
できていないため、以下に手動の工程として記載しています。

### 1. OS 側のツールを導入する

Ubuntu / WSL2 のターミナルで実行します。WSL2 の場合は Ubuntu 側の操作です。

```sh
sudo apt-get update
sudo apt-get install -y zsh git curl ca-certificates
```

`build-essential`、`pkg-config`、`libssl-dev` は、すべての利用者に一律で必要な
dotfiles の前提条件ではありません。C/C++ のコンパイルや、ネイティブ依存を
含む Rust・Python パッケージなどのビルドで必要になる開発用パッケージです。
そのような開発を行う場合は、対象プロジェクトの要件に合わせて導入します。
たとえば C/C++ のビルド環境と OpenSSL の開発ファイルが必要な場合：

```sh
sudo apt-get install -y build-essential pkg-config libssl-dev
```

これらの OS パッケージは mise の管理対象ではなく、更新も apt 側で行います。

### 2. mise と dotfiles を導入する

[mise の公式手順](https://mise.jdx.dev/getting-started.html)で mise 本体を導入し、
`~/.local/bin` を PATH に追加してください。

```sh
export PATH="$HOME/.local/bin:$PATH"
```

リポジトリを clone した後、その直下で：

```sh
mise trust
mise run setup
```

CLI → zsh プラグイン → 設定ファイルのリンクの順に導入します。
既存の設定は `.pre-mise` を付けて退避します（壊れたリンクも対象）。
バックアップが衝突する場合はリンクを変更せず停止します。再実行は可能です。
ホームへリンクするため、このチェックアウトは移動・削除せず残してください。

### 3. 表示用フォントを導入し、ターミナルで選択する

現在の表示設定は **Nerd Fonts 対応フォント**を使います。Starship の OS・Git・
Python アイコンや区切り、eza（`ls`・`ll`）のファイルアイコンが対象です。
フォントが未導入、またはターミナルで未選択だと、四角い代替文字や表示崩れが
生じることがあります。CLI のインストールだけではこの準備は完了しません。

1. [Nerd Fonts の配布ページ](https://www.nerdfonts.com/font-downloads)から、
   たとえば **FiraCode Nerd Font** をダウンロードし、展開してフォントを
   インストールします。通常版の Fira Code とは異なります。
2. 利用するターミナルのフォント設定で、インストールした Nerd Font を選びます。
3. ターミナルを開き直し、プロンプトと `ls`・`ll` のアイコンを確認します。

フォントを入れるのは、シェルの実行先ではなく **画面を表示する側の OS** です。

| 利用環境 | インストール・設定する場所 |
| --- | --- |
| Windows Terminal から WSL2 を利用 | Windows に導入し、Windows Terminal の対象プロファイルで選択 |
| エディターの統合ターミナル | ローカル OS に導入し、統合ターミナルのフォント設定で選択 |
| SSH 接続 | 接続元 PC に導入し、接続に使うターミナルで選択 |
| Linux デスクトップのターミナル | Linux 側に導入し、そのターミナルで選択 |

フォントの導入・選択は現在のスクリプトには含まれていません。
詳しくは [Starship のフォント要件](https://starship.rs/guide/#prerequisites)も参照してください。

### 4. 新しいシェルで確認する

新しいターミナルで確認後、必要なら `chsh -s /usr/bin/zsh` でログインシェルを変えます。
Home Manager から移行する場合は [移行・復旧手順](docs/mise-migration.md) も参照してください。

## 手入れする場所

| 変更したいもの | 編集するファイル |
| --- | --- |
| CLI とバージョン | `config/mise/config.toml` |
| zsh の履歴・補完・読み込み順 | `home/.zshrc` |
| PATH | `home/.zshenv`、`config/zsh/init.zsh` |
| eza の alias、Starship などの初期化 | `config/zsh/init.zsh` |
| Git、Starship の設定 | `home/.gitconfig`、`config/starship.toml` |
| zsh プラグインの取得先と固定版 | `scripts/plugins.sh` の末尾3行 |
| 配置するファイル | `scripts/link.sh` の末尾の一覧 |
| 作業コマンド | `mise.toml` |

```sh
mise run install  # ツール一覧を編集した後、不足分を導入
mise run update   # latest / lts などの指定範囲で CLI を更新
mise run plugins  # プラグインの固定版を編集した後、取得・切り替え
mise run link     # 設定リンクだけを配置
mise run check    # テストと ShellCheck
```

CLI の `latest` / `lts` は以前の指定を引き継いでいます。完全な版固定が必要なら
ツール一覧で具体的なバージョンを指定してください。プラグインは固定し、
シェル起動時のダウンロードや自動更新は行いません。プラグインの取得先にローカル変更が
あれば停止します。変更は通常 `.zshrc.local` に置いてください。

`config/mise/config.toml` がグローバル設定へリンクされるので、別ディレクトリでも
同じ CLI を利用できます。プロジェクト固有の版は各プロジェクトの `mise.toml` で
上書きします。非対話スクリプトでは `mise exec -- <command>` を使ってください。

## 個人・端末固有の設定

Git の名前・メール・署名鍵は `~/.gitconfig.local`、zsh の上書きは
`~/.zshrc.local` に置きます。後者はプラグインと CLI の初期化後、最後に読みます。
`~/.zshenv.local`、`~/.zprofile.local`、`~/.zsh_aliases` も利用できます。
これらのファイルはセットアップで変更しません。

`XDG_CONFIG_HOME` / `XDG_DATA_HOME` / `XDG_CACHE_HOME` に対応しています。
mise 設定の配置先は `MISE_GLOBAL_CONFIG_FILE` / `MISE_CONFIG_DIR` でも指定できます。
zsh の起動ファイルはホーム直下です。別の `ZDOTDIR` はこの構成では使いません。
互換用 `home/.bashrc` は残しますが自動配置しません。

## 検証

`mise run check` は隔離 HOME で、リンクの退避・再実行、zsh の履歴設定・
プラグインとローカル設定の読み込み順を確認します。検証用の ripgrep・
ShellCheck・Starship は mise が導入します。zsh と Git は OS 側のものを使います。
実プラグインを含むセットアップの確認は `mise run integration` で行えます。
これは一時 HOME に CLI をダウンロードするため時間とディスク容量が必要です。
GitHub Actions は PR・main 更新時に `check` を実行します。
