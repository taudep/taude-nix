# nix-darwin config

Lives at `~/dev/nix-darwin-config`. Used to set up Todd's Macs. Machine configs are
defined in `flake.nix` under `darwinConfigurations`:

- `Todds-MacBook-Neo` — personal laptop, user `taude`, fully set up.
- `tprekaski-LG2HQNVP4H` — Seismic work Mac, user `tprekaski`, fully set up, with an
  extra layer of work-only Homebrew packages (`workBrewModule`) on top of the shared
  base.

Both share the same base config via `mkBaseConfig` and are wired together by
`mkDarwinConfig` in `flake.nix` — same system defaults, keyboard remap, and a common
Homebrew list, plus dotfiles pulled from
[dot-local](https://github.com/taudep/dot-local) (a different home-manager module per
machine, since the work machine needs extra tool configs the personal one doesn't).
See "Setting up a new machine" below for how to add a third machine.

## Apply the config

First time on a fresh Mac (nix-darwin not installed yet, so `darwin-rebuild` doesn't exist yet):

```sh
nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/dev/nix-darwin-config
```

Every time after that, `darwin-rebuild` is on PATH:

```sh
darwin-rebuild switch --flake ~/dev/nix-darwin-config
```

Do not prefix with `sudo` — `darwin-rebuild` elevates internally as needed. If the
flake's default config name (matched by hostname) isn't the one you want, target it
explicitly: `darwin-rebuild switch --flake ~/dev/nix-darwin-config#<name>`.

On a brand-new Mac, install Homebrew itself (https://brew.sh) before the first switch —
nix-darwin manages *packages* through Homebrew but doesn't install Homebrew itself.

## Setting up a new machine

1. Clone this repo on the new machine: `git clone https://github.com/taudep/taude-nix ~/dev/nix-darwin-config`.
2. Find its real hostname: `scutil --get LocalHostName`.
3. In `flake.nix`, add a new `darwinConfigurations.<hostname>` entry calling
   `mkDarwinConfig`, so a plain `darwin-rebuild switch` (no `#name`) picks it up
   automatically.
4. Check `whoami` on that machine and pass it as `username` to `mkDarwinConfig`.
5. If it's an Intel Mac, also pass `hostPlatform = "x86_64-darwin";`.
6. Pick or write a home-manager module for it: reuse `homeHMModule`/`workHMModule` if
   its dotfile needs match one of the existing machines, or write a new module
   following the same pattern and pass it as `hmModule`. If it needs its own
   additional Homebrew packages the way the work machine does, add a new module (like
   `workBrewModule`) and pass it via `extraModules`.
7. Install Homebrew if it isn't already there, then run the first-time bootstrap command
   above.
8. If that machine needs dotfiles/settings not yet in
   [dot-local](https://github.com/taudep/dot-local), add them there first — copy the
   files in, commit, push — then reference them from `home.file` in the relevant
   home-manager module in `flake.nix`.
9. Commit and push whatever you changed in this repo back to `taudep/taude-nix` so
   it's captured for next time.

## What it does

- Nix itself is installed and managed by the Determinate Systems installer, not
  nix-darwin (`nix.enable = false`) — nix-darwin only manages the Mac-level config below.
- Installs packages listed in `environment.systemPackages` (currently `vim` and a
  nix-managed `emacs`, which Doom Emacs runs on top of via dotfiles from `dot-local`).
- Removes default Apple apps that live in `/Applications` or `/System/Applications`
  (Chess, Games, GarageBand, iMovie, Keynote, Mail, Maps, Numbers, Pages, Photo Booth,
  Safari) on every switch.
- Apps under `/System/Applications` are SIP-protected and can't be removed by a
  script even as root — the removal loop logs a skip for those rather than erroring;
  remove those by hand via Launchpad (click-and-hold the icon, click the X) if you
  want them gone.
- Installs global npm packages (currently `@bitwarden/cli`) via the activation
  script, once Homebrew's own `node` install has run.
- Manages Homebrew (`homebrew.enable`) with a base package list shared by both
  machines (`bat`, `fd`, `fmt`, `gh`, `git`, `glow`, `jq`, `node`, `ripgrep`, `tmux`,
  `uv`; casks `ghostty`, `cmux`), plus a large work-only additional list
  (`workBrewModule`) for `tprekaski-LG2HQNVP4H` covering cloud CLIs, Kubernetes
  tooling, languages/runtimes, editors, and more — see `flake.nix` for the full list.
  `onActivation.cleanup = "none"` so anything else installed via brew is left alone —
  it just isn't declaratively managed.
