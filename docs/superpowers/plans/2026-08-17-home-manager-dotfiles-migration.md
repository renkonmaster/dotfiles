# Home Manager Dotfiles Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Zsh and repository-managed dotfiles to a reproducible Home Manager configuration without activating it on the current WSL2 machine or changing the installation source of mise-managed and manually installed tools.

**Architecture:** Home Manager generates Zsh and the managed dotfiles from small Nix modules, while machine-local tools remain optional integrations guarded by command/file checks. A compatibility Zsh file remains valid for the live direct symlink until cutover; the generated Home Manager configuration is built and launched only in a temporary HOME during implementation.

**Tech Stack:** Nix flakes, Home Manager, Zsh, POSIX shell test scripts, GitHub Actions, JSON/JSONC, TOML.

## Global Constraints

- Target platform is WSL2 on `x86_64-linux`, user `renkon`, home `/home/renkon`.
- Do not run `home-manager switch`, any activation script, `chsh`, or modify `/etc/shells`.
- Do not change or remove mise, uv, agy, Rustup, pnpm, Google Cloud SDK, Windows VS Code, or apt-installed packages.
- Starship remains installed by mise; Home Manager manages only its configuration file.
- Bash is not a new configuration surface; keep `home/.bashrc` only because the live `~/.bashrc` symlink still targets it.
- Preserve `ZSH_AUTOSUGGEST_STRATEGY=(history completion)` from the user's current uncommitted `home/.zshrc` change.
- The target compatibility `home/.zshrc` contains exactly one guarded `mise activate zsh` and no unconditional activation at EOF.
- Never read, copy, print, or commit values from `~/.gitconfig.local`, `~/.gitconfig-trap`, or shell-local override files.
- Remove personal identifiers and volatile VS Code state from the current tree; do not rewrite Git history or force-push.
- Implementation occurs in an isolated worktree. The live symlink targets under `/home/renkon/dotfiles` must remain unchanged until a separately authorized cutover.

---

### Task 1: Compatibility Zsh Safety Test

**Files:**
- Create: `tests/check-compat-zsh.sh`
- Modify: `home/.zshrc:11-18,147-148`

**Interfaces:**
- Consumes: the committed compatibility `home/.zshrc` plus the user's approved autosuggestion behavior.
- Produces: a compatibility Zsh configuration that remains safe when mise and all optional user tools are absent.

- [ ] **Step 1: Write the failing compatibility test**

Create `tests/check-compat-zsh.sh`:

```sh
#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
zshrc="$repo_root/home/.zshrc"

zsh -n "$zshrc"

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

if ! output=$(
  env -i \
    HOME="$test_root/home-without-mise" \
    PATH=/usr/bin:/bin \
    TERM=dumb \
    zsh -dfc '
      source "$1"
      [[ "${(j: :)ZSH_AUTOSUGGEST_STRATEGY}" == "history completion" ]]
    ' zsh "$zshrc" 2>&1
); then
  printf '%s\n' "$output" >&2
  echo "compatibility zsh failed without optional user tools" >&2
  exit 1
fi

mkdir -p "$test_root/bin" "$test_root/home-with-mise"
printf '0\n' >"$test_root/mise-count"

cat >"$test_root/bin/mise" <<'STUB'
#!/bin/sh
set -eu

test "$#" -eq 2
test "$1" = activate
test "$2" = zsh

count=$(cat "$MISE_COUNT_FILE")
count=$((count + 1))
printf '%s\n' "$count" >"$MISE_COUNT_FILE"
printf 'typeset -gx MISE_SHELL=zsh\n'
STUB
chmod +x "$test_root/bin/mise"

env -i \
  HOME="$test_root/home-with-mise" \
  MISE_COUNT_FILE="$test_root/mise-count" \
  PATH="$test_root/bin:/usr/bin:/bin" \
  TERM=dumb \
  zsh -dfc 'source "$1"' zsh "$zshrc"

mise_count=$(cat "$test_root/mise-count")
if [ "$mise_count" -ne 1 ]; then
  echo "expected mise activation once, observed $mise_count calls" >&2
  exit 1
fi
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
sh tests/check-compat-zsh.sh
```

Expected: FAIL with `compatibility zsh failed without optional user tools`
because the runtime autosuggestion strategy is absent. A version containing the
user's duplicate final activation instead fails with two observed mise calls.

- [ ] **Step 3: Implement the minimal compatibility fix**

In `home/.zshrc`:

```zsh
ZSH_THEME=""

ZSH_AUTOSUGGEST_STRATEGY=(history completion)
```

Keep the guarded activation:

```zsh
if [[ ${MISE_SHELL:-} != zsh ]] && command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi
```

Delete the unconditional final line:

```zsh
eval "$(mise activate zsh)"
```

- [ ] **Step 4: Verify GREEN**

Run:

```bash
sh tests/check-compat-zsh.sh
git diff --check
```

Expected: both commands exit 0 and the minimal shell produces no missing-mise error.

- [ ] **Step 5: Commit the compatibility safety change**

```bash
git add tests/check-compat-zsh.sh home/.zshrc
git commit -m "fix: keep compatibility zsh startup safe"
```

---

### Task 2: Reproducible Nix Module Foundation

**Files:**
- Create: `tests/check-nix-layout.sh`
- Create: `modules/dotfiles.nix`
- Create: `modules/git.nix`
- Create: `modules/zsh.nix`
- Create: `flake.lock`
- Modify: `home.nix:1-49`

**Interfaces:**
- Consumes: `flake.nix`, `home/.aliases`, `home/.gitconfig`, and `config/starship.toml`.
- Produces: focused Home Manager modules imported by `home.nix`, with locked nixpkgs and Home Manager inputs.

- [ ] **Step 1: Write the failing layout test**

Create `tests/check-nix-layout.sh`:

```sh
#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

for file in \
  flake.lock \
  modules/dotfiles.nix \
  modules/git.nix \
  modules/zsh.nix
do
  test -s "$file" || {
    echo "missing required file: $file" >&2
    exit 1
  }
done

nix-instantiate --parse flake.nix >/dev/null
nix-instantiate --parse home.nix >/dev/null
nix-instantiate --parse modules/dotfiles.nix >/dev/null
nix-instantiate --parse modules/git.nix >/dev/null
nix-instantiate --parse modules/zsh.nix >/dev/null

nix flake metadata --no-update-lock-file >/dev/null
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
sh tests/check-nix-layout.sh
```

Expected: FAIL with `missing required file: flake.lock`.

- [ ] **Step 3: Split `home.nix` into modules**

Replace `home.nix` with:

```nix
_:

{
  imports = [
    ./modules/dotfiles.nix
    ./modules/git.nix
    ./modules/zsh.nix
  ];

  home = {
    username = "renkon";
    homeDirectory = "/home/renkon";
    stateVersion = "24.05";

    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/bin"
    ];
  };

  programs.home-manager.enable = true;
}
```

Create `modules/dotfiles.nix`:

```nix
_:

{
  # Kept during migration because the live ~/.aliases link still targets it.
  home.file.".aliases".source = ../home/.aliases;

  # Starship itself remains managed by mise; Home Manager owns only this file.
  xdg.configFile."starship.toml".source = ../config/starship.toml;
}
```

Create `modules/git.nix`:

```nix
_:

{
  # Identity and signing-key values remain in ~/.gitconfig.local.
  home.file.".gitconfig".source = ../home/.gitconfig;
}
```

Create the initial `modules/zsh.nix`:

```nix
_:

{ }
```

Do not add `home/.bashrc` or `home/.zshrc` to `home.file`.

- [ ] **Step 4: Lock flake inputs**

Run:

```bash
nix flake lock
```

Expected: `flake.lock` records exact `nixpkgs` and `home-manager` revisions and is added to the worktree only.

- [ ] **Step 5: Verify GREEN and lint the module shape**

Run:

```bash
sh tests/check-nix-layout.sh
nix shell nixpkgs#statix nixpkgs#deadnix --command sh -c 'statix check . && deadnix --fail .'
```

Expected: both commands exit 0; the previous repeated `home.*` and unused `config` warnings are gone.

- [ ] **Step 6: Commit the Nix foundation**

```bash
git add flake.lock home.nix modules tests/check-nix-layout.sh
git commit -m "refactor: split Home Manager configuration"
```

---

### Task 3: Home Manager-Generated Zsh

**Files:**
- Create: `tests/check-home-manager-zsh.sh`
- Create: `config/zsh/init.zsh`
- Modify: `modules/zsh.nix:1-5`

**Interfaces:**
- Consumes: the Home Manager module foundation from Task 2 and existing machine-local tool locations.
- Produces: a Nix Zsh package, generated `.zshrc`, managed Oh My Zsh/plugins, and guarded integration with existing tools.

- [ ] **Step 1: Write the failing generated-Zsh test**

Create `tests/check-home-manager-zsh.sh`:

```sh
#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

generation=$(
  nix build --no-link --print-out-paths \
    .#homeConfigurations.renkon.activationPackage
)

generated_zshenv="$generation/home-files/.zshenv"
generated_zshrc="$generation/home-files/.zshrc"
managed_zsh="$generation/home-path/bin/zsh"

test -s "$generated_zshenv" || {
  echo "Home Manager did not generate .zshenv" >&2
  exit 1
}
test -s "$generated_zshrc" || {
  echo "Home Manager did not generate .zshrc" >&2
  exit 1
}
test -x "$managed_zsh" || {
  echo "Home Manager did not provide zsh" >&2
  exit 1
}

test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT HUP INT TERM

if ! output=$(
  env -i \
    HOME="$test_home" \
    PATH=/usr/bin:/bin \
    TERM=dumb \
    "$managed_zsh" -dfc '
      source "$1"
      ZSH_CACHE_DIR="$HOME/.cache/oh-my-zsh"
      source "$2"
      [[ "${(j: :)ZSH_AUTOSUGGEST_STRATEGY}" == "history completion" ]]
      [[ "$(alias gemini)" == "gemini=agy" ]]
      print -r -- HM_ZSH_OK
    ' zsh "$generated_zshenv" "$generated_zshrc" 2>&1
); then
  printf '%s\n' "$output" >&2
  exit 1
fi

printf '%s\n' "$output" | grep -Fq HM_ZSH_OK

if printf '%s\n' "$output" | grep -Eq 'command not found|no such file or directory'; then
  printf '%s\n' "$output" >&2
  exit 1
fi
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
sh tests/check-home-manager-zsh.sh
```

Expected: FAIL with `Home Manager did not generate .zshrc` because `modules/zsh.nix` is empty.

- [ ] **Step 3: Configure managed Zsh and plugins**

Replace `modules/zsh.nix` with:

```nix
{ config, lib, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    package = pkgs.zsh;
    enableCompletion = true;

    autosuggestion = {
      enable = true;
      strategy = [
        "history"
        "completion"
      ];
    };

    fastSyntaxHighlighting.enable = true;

    history = {
      path = "${config.home.homeDirectory}/.zsh_history";
      size = 10000;
      save = 20000;
      share = true;
      ignoreAllDups = true;
      ignoreSpace = true;
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "";
    };

    shellAliases = {
      gemini = "agy";
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
    };

    initContent = lib.mkAfter (builtins.readFile ../config/zsh/init.zsh);
  };
}
```

This installs only Zsh, Oh My Zsh, and the two Zsh plugins through Home Manager. It does not add mise, Starship, fzf, zoxide, direnv, uv, language runtimes, or Google Cloud SDK to `home.packages`.

- [ ] **Step 4: Add guarded machine-local integrations**

Create `config/zsh/init.zsh`:

```zsh
# Custom integrations appended to the Home Manager-generated ~/.zshrc.

setopt HIST_REDUCE_BLANKS

typeset -U path PATH

[[ -d "$HOME/go/bin" ]] && path=("$HOME/go/bin" $path)
[[ -d "$HOME/.cargo/bin" ]] && path=("$HOME/.cargo/bin" $path)

export PNPM_HOME="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"
[[ -d "$PNPM_HOME/bin" ]] && path=("$PNPM_HOME/bin" $path)

[[ -d "$HOME/bin" ]] && path=("$HOME/bin" $path)
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
export PATH

if command -v dircolors >/dev/null 2>&1; then
    if [[ -r "$HOME/.dircolors" ]]; then
        eval "$(dircolors -b "$HOME/.dircolors")"
    else
        eval "$(dircolors -b)"
    fi
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

if command -v clip.exe >/dev/null 2>&1; then
    alias clip='clip.exe'
elif command -v wl-copy >/dev/null 2>&1; then
    alias clip='wl-copy'
elif command -v xsel >/dev/null 2>&1; then
    alias clip='xsel --clipboard --input'
fi

if [[ ${MISE_SHELL:-} != zsh ]] && command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi

if command -v fzf >/dev/null 2>&1; then
    if __dotfiles_fzf_init=$(fzf --zsh 2>/dev/null); then
        eval "$__dotfiles_fzf_init"
    else
        [[ -r /usr/share/doc/fzf/examples/completion.zsh ]] &&
            source /usr/share/doc/fzf/examples/completion.zsh
        [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] &&
            source /usr/share/doc/fzf/examples/key-bindings.zsh
    fi
    unset __dotfiles_fzf_init
fi

if command -v zoxide >/dev/null 2>&1 &&
    (( ! ${+functions[__zoxide_z]} )); then
    eval "$(zoxide init zsh)"
fi

if [[ -z ${STARSHIP_SHELL:-} ]] && command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

__dotfiles_gcloud_dir="$HOME/develop/mcp/google-cloud-sdk"
if [[ -r "$__dotfiles_gcloud_dir/path.zsh.inc" ]]; then
    source "$__dotfiles_gcloud_dir/path.zsh.inc"
fi
if [[ -r "$__dotfiles_gcloud_dir/completion.zsh.inc" ]]; then
    source "$__dotfiles_gcloud_dir/completion.zsh.inc"
fi
unset __dotfiles_gcloud_dir

if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
fi

if [[ -r "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi
```

- [ ] **Step 5: Verify GREEN with and without optional tools**

Run:

```bash
zsh -n config/zsh/init.zsh
sh tests/check-home-manager-zsh.sh
```

Expected: both commands exit 0. The generated config reaches `HM_ZSH_OK` with a minimal PATH and emits no missing-command/file error.

- [ ] **Step 6: Verify Home Manager did not take ownership of other tools**

Run:

```bash
generation=$(nix build --no-link --print-out-paths .#homeConfigurations.renkon.activationPackage)
find -L "$generation/home-path/bin" -maxdepth 1 -type f -printf '%f\n' | sort
```

Expected: the Home Manager generation contains its own Zsh and Home Manager support commands. It does not intentionally add mise, Starship, uv, agy, Node.js, Go, Rustup, pnpm, gcloud, or Windows `code`.

- [ ] **Step 7: Commit generated Zsh support**

```bash
git add modules/zsh.nix config/zsh/init.zsh tests/check-home-manager-zsh.sh
git commit -m "feat: manage zsh with Home Manager"
```

---

### Task 4: Git, Starship, and Shared Dotfile Cleanup

**Files:**
- Create: `tests/check-shared-config.sh`
- Modify: `home/.gitconfig:1-24`
- Modify: `config/starship.toml:117-227`

**Interfaces:**
- Consumes: the existing Git behavior and active Catppuccin Mocha Starship palette.
- Produces: portable Git paths and a single active Starship palette without changing either executable's installation source.

- [ ] **Step 1: Write the failing shared-config test**

Create `tests/check-shared-config.sh`:

```sh
#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
gitconfig="$repo_root/home/.gitconfig"
starship_config="$repo_root/config/starship.toml"

git config --file "$gitconfig" --list >/dev/null

excludes_file=$(git config --file "$gitconfig" --get core.excludesfile)
test "$excludes_file" = '~/.config/git/ignore' || {
  echo "core.excludesfile must be home-relative" >&2
  exit 1
}

include_file=$(git config --file "$gitconfig" --get include.path)
test "$include_file" = '~/.gitconfig.local' || {
  echo "local Git include was not preserved" >&2
  exit 1
}

STARSHIP_CONFIG="$starship_config" starship print-config >/dev/null

palette_count=$(grep -c '^\[palettes\.catppuccin_' "$starship_config")
test "$palette_count" -eq 1 || {
  echo "expected one Starship palette, found $palette_count" >&2
  exit 1
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
sh tests/check-shared-config.sh
```

Expected: FAIL because `core.excludesfile` is an absolute path and four Catppuccin palettes are defined.

- [ ] **Step 3: Make the Git path portable**

Change `home/.gitconfig`:

```gitconfig
[core]
	editor = code --wait
	excludesfile = ~/.config/git/ignore
```

Keep the local and conditional includes unchanged.

- [ ] **Step 4: Remove inactive Starship palettes**

Keep `[palettes.catppuccin_mocha]` and delete the complete
`catppuccin_frappe`, `catppuccin_latte`, and `catppuccin_macchiato` tables.
Do not change the active `palette = "catppuccin_mocha"` line or prompt format.

- [ ] **Step 5: Verify GREEN**

Run:

```bash
sh tests/check-shared-config.sh
git diff --check
```

Expected: both commands exit 0.

- [ ] **Step 6: Commit shared dotfile cleanup**

```bash
git add home/.gitconfig config/starship.toml tests/check-shared-config.sh
git commit -m "refactor: simplify shared dotfile configuration"
```

---

### Task 5: Declarative and Sanitized VS Code Profile

**Files:**
- Create: `tests/check-vscode.sh`
- Create: `vscode/Laptop-win/settings.jsonc`
- Create: `vscode/Laptop-win/keybindings.jsonc`
- Create: `vscode/Laptop-win/extensions.txt`
- Create: `vscode/Laptop-win/snippets/latex.json`
- Create: `vscode/Laptop-win/snippets/typst.json`
- Delete: `.vscode/Laptop-win.code-profile`

**Interfaces:**
- Consumes: useful settings, keybindings, snippets, and extension identifiers from the exported VS Code profile.
- Produces: strict-JSON-compatible JSONC files and a sorted extension list without personal or volatile global state.

- [ ] **Step 1: Write the failing VS Code privacy test**

Create `tests/check-vscode.sh`:

```sh
#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
profile_dir="$repo_root/vscode/Laptop-win"

test ! -e "$repo_root/.vscode/Laptop-win.code-profile" || {
  echo "monolithic VS Code profile still exists" >&2
  exit 1
}

for file in \
  "$profile_dir/settings.jsonc" \
  "$profile_dir/keybindings.jsonc" \
  "$profile_dir/snippets/latex.json" \
  "$profile_dir/snippets/typst.json"
do
  jq empty "$file"
done

test -s "$profile_dir/extensions.txt"
test "$(sort -u "$profile_dir/extensions.txt" | wc -l)" -eq \
     "$(wc -l < "$profile_dir/extensions.txt")"

sorted_extensions=$(mktemp)
trap 'rm -f "$sorted_extensions"' EXIT HUP INT TERM
sort "$profile_dir/extensions.txt" >"$sorted_extensions"
cmp -s "$profile_dir/extensions.txt" "$sorted_extensions" || {
  echo "extensions.txt must be sorted" >&2
  exit 1
}

if grep -ERq 'globalState|remote\.tunnels|mcpserver-|github-[A-Za-z0-9_-]+' "$profile_dir"; then
  echo "volatile VS Code state remains" >&2
  exit 1
fi

if grep -Eq 'ms-vscode\.cpptools-extension-pack|vinirossa\.vscode-gitandgithub-pack|mathematic\.vscode-latex' "$profile_dir/extensions.txt"; then
  echo "redundant extension or extension pack remains" >&2
  exit 1
fi

if grep -Eq '"extensions\.autoUpdate"[[:space:]]*:[[:space:]]*false|"update\.mode"[[:space:]]*:[[:space:]]*"none"' "$profile_dir/settings.jsonc"; then
  echo "VS Code updates are still disabled without version pinning" >&2
  exit 1
fi
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
sh tests/check-vscode.sh
```

Expected: FAIL with `monolithic VS Code profile still exists`.

- [ ] **Step 3: Create sanitized settings and keybindings**

Create `vscode/Laptop-win/settings.jsonc` as strict JSON. The absence of
`extensions.autoUpdate` and `update.mode` restores VS Code's default update
behavior:

```json
{
  "workbench.startupEditor": "none",
  "workbench.editor.enablePreview": false,
  "editor.renderWhitespace": "all",
  "files.trimTrailingWhitespace": true,
  "files.autoSave": "afterDelay",
  "editor.stickyScroll.enabled": false,
  "terminal.integrated.stickyScroll.enabled": false,
  "terminal.integrated.enableMultiLinePasteWarning": "never",
  "git.confirmSync": false,
  "git.suggestSmartCommit": false,
  "remote.autoForwardPorts": false,
  "workbench.colorTheme": "Pastel",
  "workbench.preferredHighContrastLightColorTheme": "Default High Contrast",
  "editor.tokenColorCustomizations": {
    "comments": "#77DD77"
  },
  "workbench.colorCustomizations": {
    "editorBracketHighlight.foreground1": "#d06293",
    "editorBracketHighlight.foreground2": "#f3cb76",
    "editorBracketHighlight.foreground3": "#5081eb",
    "editorBracketHighlight.foreground4": "#5be7a1",
    "editorBracketHighlight.foreground5": "#a908f3",
    "editorBracketHighlight.foreground6": "#f56b2c"
  },
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },
  "chat.tips.enabled": false,
  "chat.viewSessions.orientation": "stacked",
  "[cpp]": {
    "editor.defaultFormatter": "ms-vscode.cpptools"
  },
  "[typst]": {
    "editor.defaultFormatter": "myriad-dreamin.tinymist"
  },
  "[snippets]": {
    "editor.defaultFormatter": "vscode.json-language-features"
  },
  "[c]": {
    "editor.defaultFormatter": "ms-vscode.cpptools"
  },
  "github.copilot.enable": {
    "*": true,
    "plaintext": false,
    "markdown": true,
    "scminput": false
  },
  "workbench.iconTheme": "vscode-icons",
  "githubPullRequests.pullBranch": "never",
  "update.showReleaseNotes": false,
  "gitlens.ai.model": "vscode",
  "gitlens.ai.vscode.model": "copilot:gpt-4.1",
  "markdown.marp.browserPath": "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  "markdown.marp.openExportedHtmlInIntegratedBrowser": "window",
  "markdown.marp.browser": "chrome",
  "chatgpt.reviewDelivery": "inline"
}
```

Create `vscode/Laptop-win/keybindings.jsonc`:

```json
[
  {
    "key": "ctrl+l",
    "command": "workbench.action.terminal.clear",
    "when": "terminalFocus"
  }
]
```

- [ ] **Step 4: Create sanitized snippets**

Create `vscode/Laptop-win/snippets/latex.json`. All snippets use the `latex`
scope, `graphicx` is loaded once, and identity fields are placeholders:

```json
{
  "LaTeX Report": {
    "scope": "latex",
    "prefix": "report",
    "body": [
      "\\documentclass[${1:a4paper,11pt}]{${2:jsarticle}}",
      "",
      "\\usepackage{amsmath,amsfonts}",
      "\\usepackage{bm}",
      "\\usepackage[dvipdfmx]{graphicx}",
      "",
      "\\begin{document}",
      "\\title{${3}}",
      "\\author{${4}}",
      "\\date{${5:\\today}}",
      "\\maketitle",
      "",
      "$0",
      "",
      "\\end{document}"
    ],
    "description": "授業レポート用テンプレート"
  },
  "Physics Report": {
    "scope": "latex",
    "prefix": "physics",
    "body": [
      "\\documentclass[a4paper,12pt,dvipdfmx]{jsarticle}",
      "",
      "\\usepackage[dvipdfmx]{graphicx,xcolor}",
      "\\usepackage{tikz}",
      "\\usepackage{amsmath,amssymb}",
      "\\usepackage{bm}",
      "\\usepackage{geometry}",
      "\\usepackage{mathtools}",
      "\\usepackage{enumerate}",
      "\\geometry{top=25mm,bottom=25mm,left=25mm,right=25mm}",
      "",
      "\\title{${1:物理演習レポート}}",
      "\\author{氏名: ${2:author} \\\\ 学籍番号: ${3:student-id}}",
      "\\date{\\today}",
      "",
      "\\begin{document}",
      "\\maketitle",
      "",
      "$0",
      "",
      "\\end{document}"
    ],
    "description": "物理演習レポート用テンプレート"
  },
  "Figure": {
    "scope": "latex",
    "prefix": "fig",
    "body": [
      "\\begin{figure}[htbp]",
      "    \\centering",
      "    \\includegraphics[width=${1:\\linewidth}]{${2:figure.png}}",
      "    \\caption{${3:キャプション}}",
      "    \\label{fig:${4:label}}",
      "\\end{figure}"
    ],
    "description": "図の挿入テンプレート"
  }
}
```

Create `vscode/Laptop-win/snippets/typst.json`:

```json
{
  "Typst Report Template": {
    "scope": "typst",
    "prefix": "report",
    "body": [
      "#import \"@local/template:0.1.0\": *",
      "",
      "#show: config.with(",
      "  paper: \"a4\",",
      "  fontsize: 10pt,",
      "  lines-per-page: auto,",
      "  numbering-headings: \"1.1.1\",",
      "  cols: 1,",
      "  all-display-style: true,",
      "  show-header: false,",
      "  author: \"${1:author}\",",
      "  id: \"${2:student-id}\",",
      "  show_chapter_in_header: false,",
      ")",
      "#maketitle(",
      "  title: \"${3:title}\",",
      "  author: \"${1:author}\",",
      "  id: \"${2:student-id}\",",
      "  type: 1,",
      "  abstract: [${4:abstract}],",
      ")",
      "#pagebreak()",
      "$0"
    ],
    "description": "@local/template:0.1.0 が必要なTypst日本語レポートテンプレート"
  },
  "Typst Figure": {
    "scope": "typst",
    "prefix": "fig",
    "body": [
      "#figure(",
      "  image(\"${1:path}\", width: 80%),",
      "  caption: \"${2:caption}\",",
      ")"
    ],
    "description": "キャプション付き画像を挿入"
  }
}
```

- [ ] **Step 5: Create the sorted extension list**

Write this exact sorted list to `vscode/Laptop-win/extensions.txt`:

```text
3w36zj6.textlint
42crunch.vscode-openapi
adam-bender.commit-message-editor
bradlc.vscode-tailwindcss
charliermarsh.ruff
cval.pastel-theme
dbaeumer.vscode-eslint
donjayamanne.githistory
eamodio.gitlens
esbenp.prettier-vscode
figma.figma-vscode-extension
formulahendry.code-runner
github.codespaces
github.remotehub
github.vscode-github-actions
golang.go
howardzuo.vscode-git-tags
james-yu.latex-workshop
marp-team.marp-vscode
mhutchie.git-graph
ms-azuretools.vscode-containers
ms-azuretools.vscode-docker
ms-ceintl.vscode-language-pack-ja
ms-kubernetes-tools.vscode-kubernetes-tools
ms-python.debugpy
ms-python.python
ms-python.vscode-pylance
ms-python.vscode-python-envs
ms-vscode-remote.remote-containers
ms-vscode-remote.remote-wsl
ms-vscode.azure-repos
ms-vscode.cmake-tools
ms-vscode.cpp-devtools
ms-vscode.cpptools
ms-vscode.cpptools-themes
ms-vscode.js-debug-companion
ms-vscode.remote-repositories
ms-vsliveshare.vsliveshare
mtxr.sqltools
mtxr.sqltools-driver-pg
myriad-dreamin.tinymist
openai.chatgpt
redhat.vscode-yaml
rvest.vs-code-prettier-eslint
tomoki1207.pdf
usernamehw.errorlens
vscode-icons-team.vscode-icons
vue.volar
ziyasal.vscode-open-in-github
```

- [ ] **Step 6: Remove the monolithic profile and verify GREEN**

Delete `.vscode/Laptop-win.code-profile`, then run:

```bash
sh tests/check-vscode.sh
git diff --check
```

Expected: both commands exit 0; no exported global state or fixed identity remains in the VS Code configuration.

- [ ] **Step 7: Commit the sanitized profile**

```bash
git add .vscode vscode tests/check-vscode.sh
git commit -m "refactor: make VS Code profile declarative"
```

---

### Task 6: Repository Checks, CI, and Migration Documentation

**Files:**
- Create: `.gitignore`
- Create: `tests/check-secrets.sh`
- Create: `tests/check.sh`
- Create: `.github/workflows/check.yml`
- Create: `docs/home-manager-migration.md`
- Modify: `flake.nix:1-24`
- Modify: `README.md:1-44`

**Interfaces:**
- Consumes: all task-specific checks and the Home Manager configuration.
- Produces: one local/CI entry point, a flake check that builds the activation package, and explicit non-activating cutover/rollback instructions.

- [ ] **Step 1: Write the failing aggregate and secret checks**

Create `tests/check-secrets.sh`:

```sh
#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

patterns='gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{20,}|BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY'

if rg -n --hidden --glob '!.git/**' --glob '!graphify-out/**' \
  --pcre2 "$patterns" "$repo_root" >/dev/null
then
  echo "possible credential material found" >&2
  exit 1
fi
```

Create `tests/check.sh`:

```sh
#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

for check in "$repo_root"/tests/check-*.sh; do
  printf 'running %s\n' "${check##*/}"
  sh "$check"
done
```

Run:

```bash
sh tests/check.sh
```

Expected: FAIL before the dev shell/flake checks and final documentation are integrated, or expose any task-specific gap that must be fixed before continuing.

- [ ] **Step 2: Add repository-local ignore rules**

Create `.gitignore`:

```gitignore
# Nix build links
result
result-*

# Local development environments
.direnv/

# Generated analysis artifacts
graphify-out/
```

- [ ] **Step 3: Make the flake expose checks and a test dev shell**

Refactor `flake.nix` to bind the Home Manager configuration once and expose it
as both the user configuration and a check:

```nix
{
  description = "Home Manager configuration of renkon";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      homeConfiguration = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
      };
    in
    {
      homeConfigurations.renkon = homeConfiguration;
      checks.${system}.home-manager = homeConfiguration.activationPackage;
      packages.${system}.home-manager = home-manager.packages.${system}.home-manager;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          deadnix
          git
          jq
          ripgrep
          shellcheck
          starship
          statix
          zsh
        ];
      };
    };
}
```

The dev shell is a disposable test environment. These packages are not added
to the user's Home Manager profile and do not change the ownership policy.

- [ ] **Step 4: Add pinned CI workflow**

Create `.github/workflows/check.yml`:

```yaml
name: check

on:
  pull_request:
  push:
    branches:
      - main

permissions:
  contents: read

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: DeterminateSystems/determinate-nix-action@v3.21.9
      - name: Check repository configuration
        run: nix develop --command ./tests/check.sh
      - name: Build Home Manager configuration
        run: nix flake check --print-build-logs
```

`actions/checkout@v6` and the explicitly pinned Determinate Nix action version
were selected from their official repositories as of 2026-08-17.

- [ ] **Step 5: Document the ownership model and daily workflow**

Rewrite `README.md` in Japanese with these exact operational rules:

```markdown
## 管理方針

- Home Manager: Zsh本体、Zsh設定、Git設定、Starship設定ファイル
- mise: Node.js、Go、Starshipなど現在miseで管理しているツール
- uv: PythonプロジェクトとPython製ツール
- Windows側: VS Code本体とGUIアプリ

Home Managerの設定を編集しても、`home-manager switch` を実行するまでは
現在のホームディレクトリへ反映されません。
```

Document:

- `nix develop --command ./tests/check.sh`
- `nix flake check`
- `nix build --no-link .#homeConfigurations.renkon.activationPackage`
- Why the build is non-activating.
- How to add Zsh/dotfile settings through `modules/`.
- How to keep installing language runtimes through mise.
- How to install the VS Code extension list from PowerShell:

```powershell
Get-Content .\vscode\Laptop-win\extensions.txt |
  ForEach-Object { code --install-extension $_ }
```

- [ ] **Step 6: Write the cutover and rollback runbook**

Create `docs/home-manager-migration.md` in Japanese. It must instruct the user
to keep an existing terminal open, check backup-name collisions, and run only
after reviewing the built configuration:

```bash
for file in .zshrc .gitconfig .aliases; do
  test ! -e "$HOME/$file.pre-home-manager" || {
    echo "backup already exists: $HOME/$file.pre-home-manager" >&2
    exit 1
  }
done

nix run .#home-manager -- \
  switch -b pre-home-manager --flake .#renkon
```

The local `.#home-manager` app is exposed from the same locked Home Manager
input as the configuration, so the first-cutover CLI cannot drift from
`flake.lock`.

The runbook must explain that the initial machine has no prior Home Manager
generation, so the `.pre-home-manager` backups are the rollback source. Include
recovery from Windows PowerShell:

```powershell
wsl.exe -d Ubuntu -- /usr/bin/zsh -f
```

From the recovery shell, remove only the failed Home Manager-created link and
restore the matching backup. Do not include automatic `rm` commands in the
runbook. State that `chsh` and removal of legacy Bash/direct-link files are
separate post-migration tasks.

- [ ] **Step 7: Verify GREEN locally**

Run:

```bash
chmod +x tests/*.sh
nix develop --command ./tests/check.sh
nix flake check --print-build-logs
```

Expected: both commands exit 0 and build the locked Home Manager activation package without activation.

- [ ] **Step 8: Commit checks and documentation**

```bash
git add .gitignore .github flake.nix README.md docs/home-manager-migration.md tests/check.sh tests/check-secrets.sh
git commit -m "ci: verify Home Manager dotfiles configuration"
```

---

### Task 7: Final Non-Activating Verification and Integration Safety

**Files:**
- Modify only if verification finds a defect: files owned by Tasks 1-6.
- Do not modify: `/home/renkon/.zshrc`, `/home/renkon/.gitconfig`, `/home/renkon/.aliases`, `/home/renkon/.config/starship.toml`, `/etc/passwd`, `/etc/shells`.

**Interfaces:**
- Consumes: all implementation commits and the original live symlink targets.
- Produces: evidence that the worktree is safe to integrate and a precise list of remaining manual cutover actions.

- [ ] **Step 1: Record live state without changing it**

Run from the isolated worktree:

```bash
for file in \
  /home/renkon/.zshrc \
  /home/renkon/.gitconfig \
  /home/renkon/.aliases \
  /home/renkon/.config/starship.toml
do
  printf '%s -> %s\n' "$file" "$(readlink "$file")"
done

getent passwd renkon | awk -F: '{ print $7 }'
```

Expected: links still target `/home/renkon/dotfiles/...` and the login shell is still `/usr/bin/zsh`.

- [ ] **Step 2: Run the full fresh verification suite**

Run:

```bash
nix develop --command ./tests/check.sh
nix flake check --print-build-logs
nix build --no-link .#homeConfigurations.renkon.activationPackage
git diff --check
git status --short
```

Expected: all checks/builds exit 0; the implementation worktree is clean after its commits.

- [ ] **Step 3: Inspect generated ownership**

Run:

```bash
generation=$(nix build --no-link --print-out-paths .#homeConfigurations.renkon.activationPackage)
find -L "$generation/home-files" -maxdepth 3 \( -type f -o -type l \) -printf '%P\n' | sort
```

Expected managed user files include `.zshrc`, `.gitconfig`, `.aliases`, and `.config/starship.toml`; `.bashrc` is absent.

- [ ] **Step 4: Compare the user's existing `.zshrc` change before integration**

In the original `/home/renkon/dotfiles` checkout, run:

```bash
git diff -- home/.zshrc
```

Confirm that the target worktree version preserves the autosuggestion strategy
and removes only the duplicate unconditional mise activation. Do not discard,
stash, reset, or overwrite the user's original change.

- [ ] **Step 5: Prepare the handoff**

Report:

- Worktree path and branch.
- Exact verification commands and results.
- Confirmation that no activation, login-shell change, or live-link mutation occurred.
- The migration runbook path.
- The remaining decision about Git history rewriting.

Do not perform the real Home Manager cutover until the user separately authorizes it after reviewing this evidence.
