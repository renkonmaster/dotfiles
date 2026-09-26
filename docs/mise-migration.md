# Home Manager からの移行と復旧

## 移行

1. 正常に動いているターミナルを復旧用に残します。
2. OS の `/usr/bin/zsh` と Git、Nix に依存しない mise 本体を用意します。
   `~/.local/bin/mise` のようにホームへ導入したものを使えます。
3. Git の名前・メール・署名鍵は `~/.gitconfig.local`、シェル固有の設定は
   `~/.zshrc.local` に置きます。既存ファイルに直接書いた個人設定も移してください。
4. リポジトリ直下で `mise trust`、`mise run check` を実行します。
5. `mise run setup` を実行します。既存ファイルは自動で `.pre-mise` へ退避します。
6. 別のターミナルで起動・補完・履歴・各 CLI を確認します。必要なら
   `chsh -s /usr/bin/zsh` で OS の zsh をログインシェルにします。

退避対象は `scripts/link.sh` 末尾の一覧が正です。標準の配置先では：

- `~/.zshenv`、`~/.zprofile`、`~/.zshrc`
- `~/.aliases`、`~/.gitconfig`
- `~/.config/starship.toml`、`~/.config/mise/config.toml`

別の XDG 設定ディレクトリを使う場合はそのディレクトリ内に配置・退避します。
すでにこのチェックアウトへリンクしているファイルは変更しません。
`.pre-mise` が衝突した場合は、バックアップの用途を確認してから再実行します。

Home Manager で同じファイルを再配置しないよう、旧 `home-manager switch` の
自動化は停止します。旧設定はこのブランチの移行前コミットに残っています。

## 復旧

シェルの設定に問題があれば `/usr/bin/zsh -f` で起動します。
WSL なら PowerShell から `wsl.exe -d Ubuntu -- /usr/bin/zsh -f` でも起動できます。

対象ごとに新しいリンクを別名へ退避し、対応する `.pre-mise` を元の名前へ戻します。
たとえば `.zshrc` を戻す場合、退避名が未使用であることを確認してから：

```sh
mv ~/.zshrc ~/.zshrc.mise-disabled
mv ~/.zshrc.pre-mise ~/.zshrc
```

元のファイルがなかった対象には `.pre-mise` はありません。その場合は新リンクを
退避した状態にします。バックアップが Nix store を指すリンクの場合、復旧が終わるまで
Nix の GC を実行しないでください。

## Nix 本体について

このリポジトリのセットアップと検証は Nix を使用しません。
端末にインストールされた Nix 本体の削除は他プロジェクトにも影響するので、
セットアップスクリプトには含めません。移行確認後に不要なら別途削除します。
その際は古い `hm-session-vars.sh` の読み込み、
`~/.config/environment.d/10-home-manager.conf` などの残存設定も整理してください。
Nix 由来の補完ディレクトリは新しい zsh 設定には追加しません。
