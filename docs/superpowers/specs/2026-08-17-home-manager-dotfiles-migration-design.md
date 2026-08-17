# Home Manager Dotfiles Migration Design

## Objective

Move Zsh itself and the repository-managed dotfiles to Home Manager without
changing how the user's other tools are installed. The migration must be
prepared and verified without activating it on the current WSL2 installation.
The current interactive Zsh must continue to start throughout development and
must have an explicit rollback path during the later cutover.

## Current State

- WSL2 launches `/usr/bin/zsh` as the login shell.
- `~/.zshrc`, `~/.gitconfig`, `~/.aliases`, and
  `~/.config/starship.toml` are direct symlinks into this repository.
- No active Home Manager profile exists on the current machine.
- `home/.zshrc` has an uncommitted autosuggestion strategy addition and an
  unsafe duplicate, unconditional `mise activate zsh` at the end of the file.
- Node.js, Go, and Starship are managed through mise. uv, agy, Rustup, pnpm,
  Google Cloud SDK, and Windows VS Code use their existing installation paths.
- The tracked VS Code profile includes personal identifiers and volatile
  global state that should not be version controlled.
- The flake has no lock file, so evaluation is not reproducible.

## Management Boundary

Home Manager will manage:

- The Nix-provided Zsh package.
- The generated `~/.zshrc` and Zsh configuration.
- Oh My Zsh, Zsh autosuggestions, and fast syntax highlighting.
- Zsh history, completion, aliases, and safe PATH additions.
- The repository-managed Git configuration while preserving local includes.
- The Starship configuration file, but not the Starship executable.
- Placement of dotfiles and Home Manager generation history.

Home Manager will not change the installation source of:

- mise or the Node.js, Go, and Starship versions managed by mise.
- uv, agy, Rustup, pnpm, or Google Cloud SDK.
- Windows VS Code or other Windows applications.
- Existing apt packages during the initial migration.

Bash will not be configured through Home Manager. The existing
`home/.bashrc` will remain temporarily because the live `~/.bashrc` symlink
points to it. It is compatibility material for the migration, not an ongoing
configuration surface, and may be removed after the first successful Home
Manager activation.

## Repository Structure

The target structure is:

```text
flake.nix
flake.lock
home.nix
modules/
  dotfiles.nix
  git.nix
  zsh.nix
config/
  starship.toml
  zsh/
    init.zsh
vscode/
  Laptop-win/
    settings.jsonc
    keybindings.jsonc
    extensions.txt
    snippets/
tests/
  check.sh
.github/workflows/
  check.yml
```

Files currently targeted by live symlinks will not be deleted or moved before
the real cutover. In particular, `home/.zshrc`, `home/.gitconfig`,
`home/.aliases`, and `config/starship.toml` remain valid during development.

## Zsh Design

`programs.zsh.enable` will make Home Manager generate `~/.zshrc` and provide a
Nix Zsh package. Home Manager will configure Oh My Zsh and its plugins. Custom
logic that does not have a suitable Home Manager option will live in
`config/zsh/init.zsh` and will be included in the generated configuration.

All external integrations must degrade gracefully:

- mise is activated only if the `mise` command exists and the shell has not
  already been activated by mise.
- uv and uvx require no shell activation.
- fzf uses its native Zsh integration when available and guarded distro
  fallback scripts otherwise.
- zoxide, Starship, and direnv initialize only when their commands exist.
- Google Cloud SDK scripts are sourced only when readable from the existing
  machine-local installation path.
- Local overrides are sourced from `~/.zshrc.local` only when readable.

The uncommitted `ZSH_AUTOSUGGEST_STRATEGY=(history completion)` behavior will be
preserved. The duplicate unconditional mise activation will be removed from
the compatibility `.zshrc` and will not appear in the generated configuration.

Home Manager installing Zsh does not itself change WSL2's login shell. The
initial activation will continue to launch `/usr/bin/zsh`, which will read the
Home Manager-generated configuration. Changing the login shell to a
Home Manager-managed Zsh is a separate, explicitly authorized post-migration
step and is not part of automated implementation.

## Git and Starship Design

The shared Git configuration remains free of user name, email, and signing-key
values. It preserves:

- `~/.gitconfig.local` for user identity and signing configuration.
- Conditional trap includes for the infrastructure repositories.
- SSH commit signing, pruning, push upstream setup, branch sorting, and aliases.

Any absolute home path in the shared Git configuration will use home-relative
syntax where Git supports it. The existing local include files will not be
read, copied, or committed.

Home Manager will place `config/starship.toml` at
`~/.config/starship.toml`. It will not enable `programs.starship`, because the
Starship executable remains managed by mise. The unused Oh My Zsh prompt theme
and unused Starship palettes will be removed while keeping the active
Catppuccin Mocha prompt behavior.

## VS Code Design

The monolithic exported `.code-profile` will be replaced by declarative,
reviewable files under `vscode/Laptop-win/`:

- Editor settings without volatile global state.
- Keybindings.
- One snippet file per language.
- A sorted extension identifier list without redundant extension packs.

Personal names, student identifiers, GitHub account state, WSL tunnel state,
MCP state, chat state, and extension global state will not be retained. The
Windows-specific Chrome path may remain in the Windows-named profile because it
is host-specific but not secret. Snippet placeholders will replace personal
identity values. Duplicate LaTeX package imports and invalid or inconsistent
snippet scopes will be corrected. The local Typst package dependency will be
documented rather than silently presented as portable.

The migration removes sensitive material from the current tree only. Rewriting
Git history and force-pushing a remote is destructive and requires separate
authorization after implementation.

## Nix and Maintainability Design

- Commit `flake.lock` so nixpkgs and Home Manager inputs are reproducible.
- Split `home.nix` into focused modules for Zsh, Git, and dotfile placement.
- Remove unused Nix function arguments and repeated attribute-key style lint
  warnings.
- Keep the fixed `renkon` user, `/home/renkon` home, and `x86_64-linux` system
  because this migration targets the current WSL2 machine.
- Add repository-local ignore rules for generated Nix, direnv, and graphify
  output.
- Document the ownership rule: Home Manager owns Zsh and dotfiles; mise and the
  existing installers continue to own other tools.

## Verification Strategy

Implementation will occur in an isolated Git worktree so edits do not affect
the files referenced by the live home-directory symlinks.

The repository check will verify:

1. The compatibility Zsh configuration parses.
2. A minimal-PATH shell does not report a missing mise command.
3. Nix expressions parse and pass statix and deadnix checks.
4. `nix flake check` succeeds with the committed lock file.
5. The Home Manager activation package builds successfully.
6. The generated Home Manager `.zshrc` can be loaded by the Nix Zsh package in
   a temporary HOME/ZDOTDIR without changing the real home directory.
7. Git and Starship configurations parse.
8. VS Code settings, keybindings, snippets, and extension lists pass their
   format checks.
9. Common token and private-key patterns are absent.
10. The old personal identifiers and volatile VS Code `globalState` are absent
    from the current tree.

GitHub Actions will run the reproducible checks that do not require the current
machine's local files or credentials.

## Cutover and Rollback

Automated implementation stops before activation. The later WSL2 cutover is:

1. Record the current symlink targets and confirm no backup-name collisions.
2. Run `home-manager switch -b pre-home-manager --flake .#renkon`.
3. Open a second terminal and verify prompt, aliases, completion, mise, fzf,
   zoxide, Starship, Git, and local overrides.
4. Keep the original terminal open until the new terminal passes verification.
5. If startup fails, launch `/usr/bin/zsh -f` from WSL or from `wsl.exe`, remove
   the failed Home Manager link, and restore `.zshrc.pre-home-manager` and the
   other backups.
6. Only after stable use may the login shell be changed and the legacy Bash and
   direct-link compatibility files be removed.

The first activation has no prior Home Manager generation to roll back to, so
the `-b pre-home-manager` backups are the authoritative first-cutover recovery
mechanism.

## Success Criteria

- No tracked personal identity or volatile VS Code global state remains in the
  current tree.
- Nix inputs are locked and the Home Manager activation package builds.
- Generated Zsh configuration starts successfully with and without optional
  external commands available.
- Existing mise-managed runtimes and manually installed tools are not removed
  or re-owned by Home Manager.
- No implementation command changes the current WSL2 Home Manager generation,
  home-directory links, login shell, or `/etc/shells`.
- The repository contains an explicit, tested cutover and rollback procedure.
