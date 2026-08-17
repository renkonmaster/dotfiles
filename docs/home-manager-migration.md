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

初回適用では、既存ファイルを `.pre-home-manager` という名前へ退避します。
同名のバックアップが既にあると上書きの危険があるため、先に確認します。

```zsh
for file in .zshrc .gitconfig .aliases .config/starship.toml; do
  test ! -e "$HOME/$file.pre-home-manager" || {
    echo "backup already exists: $HOME/$file.pre-home-manager" >&2
    exit 1
  }
done
```

何か表示されて終了した場合は適用せず、既存バックアップの内容と用途を確認して
ください。自動では削除しません。

## 2. 初回だけ適用する

ビルド結果と差分を確認した後、次のコマンドを手動で実行します。

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
Home Manager の世代を戻すのではなく、次のバックアップが復旧元です。

- `~/.zshrc.pre-home-manager`
- `~/.gitconfig.pre-home-manager`
- `~/.aliases.pre-home-manager`
- `~/.config/starship.toml.pre-home-manager`

通常の Zsh が開かない場合は Windows PowerShell から、設定を読まない Zsh を
起動します。

```powershell
wsl.exe -d Ubuntu -- /usr/bin/zsh -f
```

WSL ディストリビューション名が `Ubuntu` でない場合は、`wsl.exe -l -q` で
確認した名前へ置き換えます。`zsh -f` は `.zshrc` を読まないため、壊れた
起動設定を迂回できます。

復旧シェルでは対象を `ls -l` で確認し、失敗した Home Manager 作成リンク
だけを手動で取り除いて、対応する `.pre-home-manager` バックアップを元の
名前へ戻します。対象が一致することを一つずつ確認し、自動的な一括削除は
行いません。

## 4. 移行後に別途行うこと

- `chsh` によるログインシェル変更は、この移行とは別作業です。現在既に
  `/usr/bin/zsh` なら変更不要です。
- 互換用 `.bashrc` やリポジトリへの直接リンクの削除は、Zsh と Home Manager
  の動作確認後に別作業として行います。
- Node.js、Go、Starship などのツールは引き続き mise で更新します。

この手順では、Home Manager の初回適用以外にログインシェルや WSL 設定を
変更しません。
