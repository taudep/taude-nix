# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A nix-darwin flake (`flake.nix`) that declaratively configures Todd's Macs: removes
default Apple apps, sets macOS system defaults/keyboard remap, manages Homebrew
packages, and hydrates dotfiles via home-manager. It's the whole repo — there is no
build step, package.json, or test suite; `flake.nix` (plus `flake.lock`) is the only
source of truth.

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

Apply a config to the current machine (requires `sudo`; nix-darwin does not
self-elevate):

```sh
sudo darwin-rebuild switch --flake ~/dev/nix-darwin-config
```

`<name>` above is one of the `darwinConfigurations` attribute names below (defaults to
matching the machine's hostname when omitted). First run on a machine with no
nix-darwin yet needs the bootstrap form instead, since `darwin-rebuild` doesn't exist
on PATH until after the first switch:

```sh
nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/dev/nix-darwin-config
```

## Architecture

Everything lives in one `let` block in `flake.nix`, structured as three composable
pieces:

- `mkConfiguration { username, hostPlatform }` — the nix-darwin system module: app
  removal, `system.defaults`, keyboard, Homebrew. Parameterized because it's shared
  across machines with different account names/architectures.
- `mkHomeManagerConfiguration { username }` — home-manager module that symlinks
  dotfiles. Sources files from the `dot-local` flake input
  (`github:taudep/dot-local`, `flake = false` — it's just raw files, not a flake) via
  `home.file.<path>.source = "${dot-local}/...";`. `home-manager.backupFileExtension
  = "backup"` is set at the call site so real pre-existing dotfiles get backed up
  instead of blocking activation the first time a machine switches.
- `mkDarwinConfig { username, hostPlatform }` — wires the two together into a
  `nix-darwin.lib.darwinSystem`. This is what each `darwinConfigurations.<name>`
  output actually calls.

`darwinConfigurations` currently has one real machine (`Todds-MacBook-Neo`) and two
placeholders (`CHANGEME-mac-mini`, `CHANGEME-work-computer`) waiting to be renamed to
real hostnames and applied — see README.md's "Setting up a new machine" for that
walkthrough. All three currently resolve to an identical config; per-machine
differences (e.g. work-only tools) should go through `mkDarwinConfig`'s
`username`/`hostPlatform` args or by adding new params, not by hand-editing a
duplicated module.

`system.primaryUser` and `users.users.${username}.home` must both be set for any
user-scoped option (Homebrew, home-manager) to evaluate — nix-darwin's home-manager
integration derives `home.homeDirectory` from `users.users.${username}.home`, it does
not accept it being set directly on the home-manager side.

### Related repos

- [`taudep/dot-local`](https://github.com/taudep/dot-local) — the actual dotfile
  contents (`zsh/`, `git/`, `starship/`, `doom/`), consumed by this repo's
  `mkHomeManagerConfiguration`. Adding a new dotfile means adding the file there first,
  then adding a `home.file` entry here pointing at it.

### Activation script notes (`system.activationScripts.postActivation.text`)

Runs after Homebrew's own activation, so brew-installed binaries (e.g. `node`/`npm`)
are available by the time it runs. Two things it currently does beyond app removal:
apps under `/System/Applications` are SIP-protected and can't be `rm`'d even as root —
that loop expects `rm` to fail there and just logs a skip rather than erroring the
whole activation. The npm-global-install step probes both `/opt/homebrew/bin/npm`
(Apple Silicon) and `/usr/local/bin/npm` (Intel) since Homebrew's prefix differs by
architecture and activation scripts don't reliably inherit an interactive shell PATH.
