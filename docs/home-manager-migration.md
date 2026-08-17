# Home Manager 初回移行手順

この手順は、既存の dotfiles への直接リンクを Home Manager 管理へ切り替える
ためのものです。ビルド検証だけでは現在のホームディレクトリは変わりません。
実際に変わるのは「適用」を明示的に実行した時だけです。

## 1. 適用前に確認する

作業中の Zsh とは別に、正常に動いている WSL のターミナルを一つ開いたままに
してください。問題が起きた時の復旧用なので、新しい Zsh の確認が終わるまで
閉じません。

リポジトリ直下で、まず非適用の検証を行います。

```zsh
nix develop --command ./tests/check.sh
nix flake check --print-build-logs
nix build --no-link .#homeConfigurations.renkon.activationPackage
```

これらは構成を評価・ビルドするだけで、`~/.zshrc`、ログインシェル、
既存のシンボリックリンクを変更しません。

生成物には、明示的に指定した `.zshrc` だけでなく `.zshenv` と `.zprofile` も
含まれます。現在の `.zshenv` が行っていた Cargo の PATH 追加は
`home.sessionPath` へ移行済みです。元のファイル自体は復旧用に退避します。

`switch -b` は通常ファイルを退避できますが、Home Manager 以外が作った既存の
シンボリックリンクは退避しません。そのため、生成される全ファイルを次の一覧で
管理し、先に `.pre-home-manager` へ明示的に移します。

```zsh
managed_files=(
  .aliases
  .cache/.keep
  .cache/oh-my-zsh/.keep
  .config/environment.d/10-home-manager.conf
  .config/starship.toml
  .config/systemd/user/tray.target
  .gitconfig
  .local/state/.keep
  .zprofile
  .zshenv
  .zshrc
)

for file in $managed_files; do
  current="$HOME/$file"
  backup="$current.pre-home-manager"

  if [[ -e "$current" || -L "$current" ]]; then
    if [[ -e "$backup" || -L "$backup" ]]; then
      echo "backup already exists: $backup" >&2
      exit 1
    fi
    printf 'will back up: %s -> %s\n' "$current" "$backup"
  fi
done

unset current backup file
```

`backup already exists` と表示された場合は適用せず、既存バックアップの内容と
用途を確認してください。`will back up` は、次の手順で移動する対象の一覧です。
内容に意図しないファイルがないことを確認します。

## 2. 初回だけ適用する

表示された対象を確認した後、同じターミナルで次の退避を行います。これは削除
ではなく、同じディレクトリ内で名前を変更する操作です。

```zsh
for file in $managed_files; do
  current="$HOME/$file"
  backup="$current.pre-home-manager"

  if [[ -e "$current" || -L "$current" ]]; then
    if [[ -e "$backup" || -L "$backup" ]]; then
      echo "backup appeared during cutover: $backup" >&2
      exit 1
    fi
    mv -- "$current" "$backup"
  fi
done

unset current backup file managed_files
```

退避がすべて成功した直後に、次の適用コマンドを手動で実行します。

```zsh
nix run .#home-manager -- \
  switch -b pre-home-manager --flake .#renkon
```

`.#home-manager` は、この構成と同じ `flake.lock` に固定された Home Manager
入力から提供されます。そのため、初回適用に使う CLI と構成側の Home Manager
の版がずれません。

適用後は、開いたままの復旧用ターミナルを残して新しい WSL ターミナルを開き、
Zsh の起動、補完、mise、Starship、Git 設定を確認します。問題がなければ、
その後に復旧用ターミナルを閉じます。

## 3. 初回適用で問題が起きた場合

この PC には移行前の Home Manager generation がないため、初回適用直後は
Home Manager の世代を戻すのではなく、`managed_files` のうち実際に存在した
ファイルに作成された `.pre-home-manager` バックアップが復旧元です。現在の
PC では `.zshenv` もこの対象に含まれます。

通常の Zsh が開かない場合は Windows PowerShell から、設定を読まない Zsh を
起動します。

```powershell
wsl.exe -d Ubuntu -- /usr/bin/zsh -f
```

WSL ディストリビューション名が `Ubuntu` でない場合は、`wsl.exe -l -q` で
確認した名前へ置き換えます。`zsh -f` は `.zshrc` を読まないため、壊れた
起動設定を迂回できます。

復旧シェルでは上の `managed_files` 一覧を使い、対象を `ls -l` で確認します。
失敗した Home Manager 作成リンクだけを手動で取り除き、対応する
`.pre-home-manager` バックアップを元の名前へ `mv` で戻します。`.zshenv` と
`.zprofile` も確認対象です。対象が一致することを一つずつ確認し、自動的な
一括削除は行いません。

## 4. 移行後に別途行うこと

- `chsh` によるログインシェル変更は、この移行とは別作業です。現在既に
  `/usr/bin/zsh` なら変更不要です。
- 互換用 `.bashrc` やリポジトリへの直接リンクの削除は、Zsh と Home Manager
  の動作確認後に別作業として行います。
- Node.js、Go、Starship などのツールは引き続き mise で更新します。

この手順では、Home Manager の初回適用以外にログインシェルや WSL 設定を
変更しません。
