# nix-darwin config

Lives at `~/dev/nix-darwin-config`. Used to set up new Macs. Machine configs are defined
in `flake.nix` under `darwinConfigurations`:

- `Todds-MacBook-Neo` — this laptop, fully set up.
- `CHANGEME-mac-mini` — placeholder for the Mac mini, not yet renamed/applied.
- `CHANGEME-work-computer` — placeholder for the work machine, not yet renamed/applied.

All three share the same config via the `mkDarwinConfig` function in `flake.nix` — same
Homebrew packages, system defaults, keyboard remap, and dotfiles from
[dot-local](https://github.com/taudep/dot-local). See "Setting up a new machine" below
for how to turn a placeholder into a real one.

## Apply the config

First time on a fresh Mac (nix-darwin not installed yet, so `darwin-rebuild` doesn't exist yet):

```sh
nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/dev/nix-darwin-config
```

Every time after that, `darwin-rebuild` is on PATH:

```sh
sudo darwin-rebuild switch --flake ~/dev/nix-darwin-config
```

`sudo` is required — nix-darwin no longer self-elevates; system activation must run as
root. If the flake's default config name (matched by hostname) isn't the one you want,
target it explicitly: `sudo darwin-rebuild switch --flake ~/dev/nix-darwin-config#<name>`.

On a brand-new Mac, install Homebrew itself (https://brew.sh) before the first switch —
nix-darwin manages *packages* through Homebrew but doesn't install Homebrew itself.

## Setting up a new machine (mac-mini / work-computer)

1. Clone this repo on the new machine: `git clone https://github.com/taudep/taude-nix ~/dev/nix-darwin-config`.
2. Find its real hostname: `scutil --get LocalHostName`.
3. In `flake.nix`, rename the placeholder attribute (e.g. `"CHANGEME-mac-mini"`) to that
   hostname, so a plain `darwin-rebuild switch` (no `#name`) picks it up automatically.
4. Check `whoami` on that machine. If the macOS account isn't `taude` (likely on a work
   computer with a managed account), change that config's call to
   `mkDarwinConfig { username = "your-account-name"; }`.
5. If it's an Intel Mac, also pass `hostPlatform = "x86_64-darwin";`.
6. Install Homebrew if it isn't already there, then run the first-time bootstrap command
   above.
7. If that machine has its own dotfiles/settings worth keeping (a different
   `.gitconfig`, work-specific tools, etc.), pull them into
   [dot-local](https://github.com/taudep/dot-local) the same way we did for this laptop —
   copy the files in, commit, push — then reference them from `home.file` in
   `mkHomeManagerConfiguration` in `flake.nix` (add machine-specific ones behind the
   `username`/hostname the same way `mkConfiguration` is parameterized, if they shouldn't
   apply to every machine).
8. Commit and push whatever you changed in this repo (the renamed attribute, any
   `username`/`hostPlatform` overrides) back to `taudep/taude-nix` so it's captured for
   next time.

## What it does

- Nix itself is installed and managed by the Determinate Systems installer, not
  nix-darwin (`nix.enable = false`) — nix-darwin only manages the Mac-level config below.
- Installs packages listed in `environment.systemPackages`.
- Removes default Apple apps that live in `/Applications` (GarageBand, iMovie, Safari,
  Keynote/Numbers/Pages if present) on every switch.
- Apps that live in `/System/Applications` (Chess, Games, Mail, Maps, Photo Booth) are
  SIP-protected and can't be removed by a script. Remove those by hand via Launchpad
  (click-and-hold the icon, click the X) if you want them gone.
- Manages Homebrew (`homebrew.enable`) and installs: `uv`, `tmux`, `fd`, `fmt`, `bat`,
  `gh`, `glow`, `ripgrep`, `jq`, and the `ghostty` cask. `onActivation.cleanup = "none"`
  so anything else you've installed via brew (emacs-plus, starship, hugo, etc.) is left
  alone — it just isn't declaratively managed yet.
