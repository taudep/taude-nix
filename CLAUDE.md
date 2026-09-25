# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A nix-darwin flake (`flake.nix`) that declaratively configures Todd's two Macs — a
personal machine and a Seismic work machine: removes default Apple apps, sets macOS
system defaults/keyboard remap, manages Homebrew packages, and hydrates dotfiles via
home-manager. It's the whole repo — there is no build step, package.json, or test
suite; `flake.nix` (plus `flake.lock`) is the only source of truth.

Nix itself is installed and managed by the Determinate Systems installer, not
nix-darwin (`nix.enable = false` in the flake) — don't add `nix.settings.*` options,
they'd be silently ignored since nix-darwin isn't managing `/etc/nix/nix.conf`.

## Commands

Validate the flake after any edit (fast, evaluation only, no build):

```sh
nix flake check --no-build
```

Do a full build to catch build-time errors without touching the running system:

```sh
nix build .#darwinConfigurations.<name>.system --no-link --print-out-paths
```

Apply a config to the current machine. `darwin-rebuild` elevates internally as
needed — do not prefix with `sudo`:

```sh
darwin-rebuild switch --flake ~/dev/nix-darwin-config
```

`<name>` above is one of the `darwinConfigurations` attribute names below (defaults to
matching the machine's hostname when omitted). First run on a machine with no
nix-darwin yet needs the bootstrap form instead, since `darwin-rebuild` doesn't exist
on PATH until after the first switch:

```sh
nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/dev/nix-darwin-config
```

## Architecture

Everything lives in one `let` block in `flake.nix`, structured as composable pieces:

- `mkBaseConfig { username, hostPlatform }` — the nix-darwin system module shared by
  both machines: app removal, `system.defaults`, keyboard, nix-managed Emacs (base for
  Doom), and the base Homebrew list (`bat`, `fd`, `gh`, `git`, `jq`, `node`,
  `ripgrep`, `tmux`, `uv`; casks `ghostty`, `cmux`). Parameterized because it's shared
  across machines with different account names/architectures.
- `workBrewModule` — an additive module of work-only Homebrew taps/brews/casks
  (cloud CLIs, Kubernetes tools, languages, editors, etc.), composed on top of
  `mkBaseConfig` only for the work machine. List options (taps/brews/casks) are
  concatenated by the nix module system, so this doesn't need to repeat the base list.
- `homeHMModule` / `workHMModule` — per-machine home-manager modules that symlink
  dotfiles. Sources files from the `dot-local` flake input
  (`github:taudep/dot-local`, `flake = false` — it's just raw files, not a flake) via
  `home.file.<path>.source = "${dot-local}/...";`. The two modules diverge because the
  work machine has extra tool configs (tmux, k9s, lazygit, zellij, btop, glow, ghostty,
  a secrets-bootstrap script) that the personal machine doesn't need.
  `home-manager.backupFileExtension = "backup"` is set at the `mkDarwinConfig` call
  site so real pre-existing dotfiles get backed up instead of blocking activation the
  first time a machine switches.
- `mkDarwinConfig { username, hostPlatform, hmModule, extraModules }` — wires the base
  config, any `extraModules` (e.g. `workBrewModule`), and the given `hmModule` together
  into a `nix-darwin.lib.darwinSystem`. This is what each `darwinConfigurations.<name>`
  output actually calls.

`darwinConfigurations` currently has two real machines:

- `Todds-MacBook-Neo` — personal Mac, user `taude`, uses `homeHMModule`, no extra
  Homebrew modules.
- `tprekaski-LG2HQNVP4H` — Seismic work Mac, user `tprekaski`, uses `workHMModule`
  plus `workBrewModule` for the larger work-only tool set.

There are no placeholder/unassigned machine entries — every entry in
`darwinConfigurations` is a real, applied machine. Per-machine differences should go
through `mkDarwinConfig`'s args (`username`, `hostPlatform`, `hmModule`,
`extraModules`) or by adding new params, not by hand-editing a duplicated module.

`system.primaryUser` and `users.users.${username}.home` must both be set for any
user-scoped option (Homebrew, home-manager) to evaluate — nix-darwin's home-manager
integration derives `home.homeDirectory` from `users.users.${username}.home`, it does
not accept it being set directly on the home-manager side.

### Related repos

- [`taudep/dot-local`](https://github.com/taudep/dot-local) — the actual dotfile
  contents (`zsh/`, `git/`, `tmux/`, `starship/`, `doom/`, plus work-only tool configs
  like `k9s/`, `lazygit/`, `zellij/`, `btop/`, `glow/`, `ghostty/`), consumed by
  `homeHMModule`/`workHMModule`. Adding a new dotfile means adding the file there
  first, then adding a `home.file` entry here pointing at it.

### Activation script notes (`system.activationScripts.postActivation.text`, in `mkBaseConfig`)

Runs after Homebrew's own activation, so brew-installed binaries (e.g. `node`/`npm`)
are available by the time it runs. Two things it currently does beyond app removal:
apps under `/System/Applications` are SIP-protected and can't be `rm`'d even as root —
that loop expects `rm` to fail there and just logs a skip rather than erroring the
whole activation. The npm-global-install step probes both `/opt/homebrew/bin/npm`
(Apple Silicon) and `/usr/local/bin/npm` (Intel) since Homebrew's prefix differs by
architecture and activation scripts don't reliably inherit an interactive shell PATH.
