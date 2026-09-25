{
  description = "nix-darwin configs — Todds-MacBook-Neo (home) and tprekaski-LG2HQNVP4H (work)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Plain dotfiles repo, not a flake — just used as a source of files for
    # home-manager to symlink into place.
    dot-local = {
      url = "github:taudep/dot-local";
      flake = false;
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, dot-local }:
  let

    # ── Shared system config ─────────────────────────────────────────────
    # Everything both machines have in common: macOS defaults, keyboard,
    # base Homebrew list, and emacs (nix-managed so doom can run on top).
    mkBaseConfig = { username, hostPlatform }: { pkgs, ... }: {
      environment.systemPackages = [
        pkgs.vim
        pkgs.emacs  # GNU Emacs from nixpkgs; Doom config lives in dot-local/doom/
      ];

      # Nix itself is managed by the Determinate Systems installer.
      nix.enable = false;

      # Remove default Apple apps we don't want on a fresh Mac.
      # SIP-protected apps (/System/Applications) are skipped with a warning.
      system.activationScripts.postActivation.text = ''
        echo "Removing default Apple apps..." >&2
        apps=(
          "Chess"
          "Games"
          "GarageBand"
          "iMovie"
          "Keynote"
          "Mail"
          "Maps"
          "Numbers"
          "Pages"
          "Photo Booth"
          "Safari"
        )
        for app in "''${apps[@]}"; do
          for dir in /Applications /System/Applications; do
            path="$dir/$app.app"
            if [ -d "$path" ]; then
              if rm -rf "$path" 2>/dev/null; then
                echo "  removed $path" >&2
              else
                echo "  skipped $path (protected by SIP, remove manually if desired)" >&2
              fi
            fi
          done
        done

        echo "Installing global npm packages..." >&2
        npm_bin=""
        for candidate in /opt/homebrew/bin/npm /usr/local/bin/npm; do
          if [ -x "$candidate" ]; then
            npm_bin="$candidate"
            break
          fi
        done
        if [ -n "$npm_bin" ]; then
          "$npm_bin" install -g @bitwarden/cli
        else
          echo "  skipped: npm not found (is the homebrew 'node' formula installed?)" >&2
        fi
      '';

      system.keyboard.enableKeyMapping = true;
      system.keyboard.remapCapsLockToControl = true;

      system.defaults = {
        NSGlobalDomain."com.apple.swipescrolldirection" = false;
        trackpad.Clicking = true;
        finder = {
          AppleShowAllExtensions = true;
          AppleShowAllFiles = true;
          FXEnableExtensionChangeWarning = false;
        };
      };

      # Base Homebrew packages shared by both machines.
      # cleanup = "none" so unmanaged brews/casks are left alone.
      homebrew = {
        enable = true;
        taps = [
          "manaflow-ai/cmux"
        ];
        brews = [
          "bat"
          "fd"
          "fmt"
          "gh"
          "git"
          "glow"
          "jq"
          "node"
          "ripgrep"
          "tmux"
          "uv"
        ];
        casks = [
          "ghostty"
          "cmux"
        ];
        onActivation = {
          autoUpdate = true;
          upgrade = true;
          cleanup = "none";
        };
      };

      system.configurationRevision = self.rev or self.dirtyRev or null;
      system.stateVersion = 6;
      nixpkgs.hostPlatform = hostPlatform;
      system.primaryUser = username;
      users.users.${username}.home = "/Users/${username}";
    };

    # ── Work machine extra Homebrew packages ─────────────────────────────
    # This module is composed additively on top of mkBaseConfig — list
    # options (taps/brews/casks) are concatenated by the nix module system.
    workBrewModule = { ... }: {
      homebrew = {
        taps = [
          "anomalyco/tap"
          "atlassian/acli"
          "azure/azd"
          "drolosoft/tap"
          "emin-ozata/tap"
          "hashicorp/tap"
          "snowflakedb/snowflake-cli"
          "snyk/tap"
          "xo/xo"
        ];
        brews = [
          # Dev / cloud
          "act"
          "ansible"
          "autojump"
          "awscli"
          "azure-cli"
          "azd"
          "fzf"
          "git-filter-repo"
          "go"
          "hugo"
          "just"
          "llm"
          "loc"
          "mackup"
          "opencode"
          "plantuml"
          "tlrc"
          "tree"
          "xdg-ninja"
          "yq"
          # Python
          "pipx"
          "pyenv"
          "python@3.12"
          "python@3.13"
          "python@3.14"
          # Ruby
          "chruby"
          "ruby"
          "ruby-install"
          # Kubernetes
          "helm"
          "k9s"
          "kubernetes-cli"
          "kustomize"
          # Editors / TUIs
          "broot"
          "btop"
          "lazygit"
          "neovim"
          "vim"
          "zellij"
          # Data / DB
          "duckdb"
          "pgcli"
          "postgresql@18"
          "redis"
          "snowflake-cli"
          "usql"
          # Other
          "acli"
          "cmux-resurrect"
          "ffmpeg"
          "gator"
          "lazycut"
          "podman"
          "snyk"
          "terraform"
        ];
        casks = [
          "1password-cli"
          "copilot-cli"
          "openlens"
          "podman-desktop"
          "temurin"
          "zettlr"
        ];
      };
    };

    # ── Home machine HM config (taude) ───────────────────────────────────
    homeHMModule = { pkgs, ... }: {
      home.stateVersion = "24.05";
      home.username = "taude";
      home.file = {
        ".zshrc".source                    = "${dot-local}/zsh/zshrc";
        ".zprofile".source                 = "${dot-local}/zsh/zprofile";
        ".gitconfig".source                = "${dot-local}/git/gitconfig";
        ".config/starship.toml".source     = "${dot-local}/starship/starship.toml";
        ".config/doom/config.el".source    = "${dot-local}/doom/config.el";
        ".config/doom/init.el".source      = "${dot-local}/doom/init.el";
        ".config/doom/packages.el".source  = "${dot-local}/doom/packages.el";
      };
    };

    # ── Work machine HM config (tprekaski) ───────────────────────────────
    workHMModule = { pkgs, ... }: {
      home.stateVersion = "24.05";
      home.username = "tprekaski";
      home.file = {
        # Shell
        ".zshrc".source               = "${dot-local}/zsh/zshrc.work";
        ".zprofile".source            = "${dot-local}/zsh/zprofile.work";
        ".bash_aliases".source        = "${dot-local}/zsh/bash_aliases";
        ".p10k.zsh".source            = "${dot-local}/zsh/p10k.zsh";
        # Tmux
        ".tmux.conf".source           = "${dot-local}/tmux/tmux.conf";
        # Git (shared config, no user-specific secrets)
        ".gitconfig".source           = "${dot-local}/git/gitconfig";
        # Secrets bootstrap script (populated by op CLI at shell startup)
        ".local/bin/load-secrets" = {
          source     = "${dot-local}/scripts/load-secrets";
          executable = true;
        };
        # Doom Emacs
        ".config/doom/config.el".source   = "${dot-local}/doom/config.el";
        ".config/doom/init.el".source     = "${dot-local}/doom/init.el";
        ".config/doom/packages.el".source = "${dot-local}/doom/packages.el";
        # Tool configs (audited: no secrets)
        ".config/ghostty/config.toml".source  = "${dot-local}/ghostty/config.toml";
        ".config/k9s/config.yaml".source      = "${dot-local}/k9s/config.yaml";
        ".config/k9s/aliases.yaml".source     = "${dot-local}/k9s/aliases.yaml";
        ".config/lazygit/config.yml".source   = "${dot-local}/lazygit/config.yml";
        ".config/zellij/config.kdl".source    = "${dot-local}/zellij/config.kdl";
        ".config/btop/btop.conf".source       = "${dot-local}/btop/btop.conf";
        ".config/glow/glow.yml".source        = "${dot-local}/glow/glow.yml";
      };
    };

    # ── Builder ──────────────────────────────────────────────────────────
    mkDarwinConfig = { username, hostPlatform ? "aarch64-darwin", hmModule, extraModules ? [] }:
      nix-darwin.lib.darwinSystem {
        modules = [
          (mkBaseConfig { inherit username hostPlatform; })
        ] ++ extraModules ++ [
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.${username} = hmModule;
          }
        ];
      };

  in
  {
    # Home Mac (personal):
    #   darwin-rebuild switch --flake .#Todds-MacBook-Neo
    darwinConfigurations."Todds-MacBook-Neo" = mkDarwinConfig {
      username = "taude";
      hmModule = homeHMModule;
    };

    # Work Mac (Seismic):
    #   darwin-rebuild switch --flake .#tprekaski-LG2HQNVP4H
    darwinConfigurations."tprekaski-LG2HQNVP4H" = mkDarwinConfig {
      username     = "tprekaski";
      hmModule     = workHMModule;
      extraModules = [ workBrewModule ];
    };
  };
}
