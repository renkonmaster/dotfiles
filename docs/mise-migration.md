# Home Manager から mise への移行

この文書は後日の適用用です。今回の書き換えでは以下のコマンドを実行していません。
新構成の検証が済むまでは適用せず、現在のターミナルも復旧用に残してください。

## 準備

1. Nix に依存しない mise を公式手順で導入します。Home Manager 提供の mise
   しかない場合は、先に `~/.local/bin/mise` などの独立した実体を用意します。
2. zsh と Git が OS 側にあることを確認します。対象は Ubuntu / WSL2 です。
3. このリポジトリの `mise.toml` と `config/mise/config.toml` を読みます。
   `mise trust` の後、必要な時点で README の検証を実行します。
4. `XDG_CONFIG_HOME` などを変更している場合は README の配置先の注意を確認します。
5. 今後このホームへ `home-manager switch` を実行する自動化があれば停止します。
   両方から同じファイルを管理しないようにしてください。

## 既存設定の退避

Home Manager の Nix store リンクも、通常ファイルも、壊れたリンクも対象です。
Home Manager を使っていなかった場合にも同じ手順を使えます。
以下は zsh 用で、サブシェル内で全対象の衝突を確認してから退避します。

```zsh
(
  set -e
  managed_files=(
    .zshenv
    .zprofile
    .zshrc
    .aliases
    .gitconfig
    .config/mise/config.toml
    .config/starship.toml
  )
  for file in $managed_files; do
    backup="$HOME/$file.pre-mise"
    if [[ -e "$backup" || -L "$backup" ]]; then
      print -u2 -- "backup already exists: $backup"
      exit 1
    fi
  done
  for file in $managed_files; do
    current="$HOME/$file"
    if [[ -e "$current" || -L "$current" ]]; then
      mv -- "$current" "$current.pre-mise"
    fi
  done
)
```

失敗した場合はここで止め、どこまで退避されたか確認します。
`.pre-mise` がすでにある場合は上書きせず、以前の移行・復旧状況を確認します。
設定ファイルへ直接書いていた個人設定は対応する `.local` へ移してください。
バックアップが Nix store へのリンクなら、復旧が終わるまでは Nix の GC を行いません。

## 適用

バックアップが完了した後、リポジトリ直下で実行します。

```zsh
mise run setup
```

設定リンクの配置は `mise dotfiles apply` で行い、`--force` は使いません。
その後、新しい mise プロセスで配置済みのグローバル設定を読み直し、CLI を導入します。
途中で失敗した場合はエラーを解消して同じタスクを再実行できます。
既存の `~/.oh-my-zsh` や Bash の設定は削除せず、新プラグインは別ディレクトリに置きます。

新しいターミナルで履歴・補完・autosuggestions・syntax highlighting・Starship・
各 CLI を確認します。必要ならログインシェルを `/usr/bin/zsh` に変更します。

## 復旧

zsh が起動できない場合は、WSL の別ターミナルで `/usr/bin/zsh -f` を使います。
Windows からは `wsl.exe -d Ubuntu -- /usr/bin/zsh -f` で起動できます。
ディストリビューション名は自分の環境に合わせます。

上の `managed_files` にあるパスごとに現在のリンク先を確認し、このリポジトリを
指す新リンクだけを別名へ退避したうえで、対応する `.pre-mise` を元の名前へ戻します。
バックアップのなかったファイルは、新リンクを退避した状態に戻します。
Home Manager の世代がある環境では、保持してある旧構成による再適用も復旧手段です。
旧 Nix 構成は Git の `main` ブランチから参照できます。

## 動作確認後

Nix / Home Manager 本体、旧世代、旧プラグインはこのセットアップでは削除しません。
不要になった場合のみ別作業で整理します。Home Manager が配置していた
`~/.config/environment.d/10-home-manager.conf`、
`~/.config/systemd/user/tray.target`、`hm-session-vars.sh` の読み込みも確認対象です。
Nix を他用途で使う場合があるため、一括削除はしません。
