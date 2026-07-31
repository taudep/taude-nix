# nix-darwin config

Lives at `~/dev/nix-darwin-config`. Used to set up new Macs (host config: `Todds-MacBook-Neo` in `flake.nix`).

## Apply the config

First time on a fresh Mac (nix-darwin not installed yet, so `darwin-rebuild` doesn't exist yet):

```sh
nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/dev/nix-darwin-config
```

Every time after that, `darwin-rebuild` is on PATH:

```sh
darwin-rebuild switch --flake ~/dev/nix-darwin-config
```

Don't prefix either command with `sudo` yourself — `darwin-rebuild` elevates via sudo
internally for just the parts that need root and will prompt for your password when it
gets there. Running the whole thing as root can miss your user-level Nix config.

On a brand-new Mac, install Homebrew itself (https://brew.sh) before the first switch —
nix-darwin manages *packages* through Homebrew but doesn't install Homebrew itself.

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
