{
  description = "Example nix-darwin system flake";

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
    # Shared system config, parameterized per machine. `username` is the
    # macOS account nix-darwin/home-manager operate as; `hostPlatform` is
    # "aarch64-darwin" for Apple Silicon or "x86_64-darwin" for Intel.
    mkConfiguration = { username, hostPlatform }: { pkgs, ... }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages =
        [ pkgs.vim
        ];

      # Nix itself is installed and managed by the Determinate Systems
      # installer, so don't let nix-darwin also manage the daemon/nix.conf
      # (it already enables flakes + nix-command).
      nix.enable = false;

      # Remove default Apple apps we don't want on a fresh Mac.
      # Note: apps under /System/Applications are part of the SIP-sealed
      # system volume and cannot be deleted even as root; those are skipped
      # with a warning instead of failing the whole activation. Apps under
      # /Applications are ordinary bundles and get removed normally.
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

      # Caps Lock acts as an extra Control key.
      system.keyboard.enableKeyMapping = true;
      system.keyboard.remapCapsLockToControl = true;

      system.defaults = {
        # Traditional (reversed) scroll direction, not Apple's "natural" default.
        NSGlobalDomain."com.apple.swipescrolldirection" = false;

        trackpad.Clicking = true; # tap to click

        finder = {
          AppleShowAllExtensions = true;
          AppleShowAllFiles = true;
          FXEnableExtensionChangeWarning = false;
        };
      };

      # Let nix-darwin drive Homebrew (via `brew bundle`) for the handful of
      # things that aren't practical through nixpkgs on macOS.
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
          # Don't uninstall other brews/casks you already have installed
          # that aren't listed here (e.g. emacs-plus, starship, hugo) —
          # only add "uninstall"/"zap" once this list is meant to be the
          # full source of truth.
          cleanup = "none";
        };
      };

      # Enable alternative shell support in nix-darwin.
      # programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      nixpkgs.hostPlatform = hostPlatform;

      # Required for user-scoped options (e.g. homebrew) since nix-darwin
      # activation runs as root.
      system.primaryUser = username;

      # Declares the existing macOS account (nix-darwin doesn't create it) so
      # home-manager can derive home.homeDirectory from it.
      users.users.${username}.home = "/Users/${username}";
    };

    # Dotfiles hydrated from https://github.com/taudep/dot-local, symlinked
    # into place by home-manager. Existing real files at these paths get
    # backed up with a ".backup" suffix the first time this switches.
    mkHomeManagerConfiguration = { username }: { pkgs, ... }: {
      home.stateVersion = "24.05";
      home.username = username;

      home.file = {
        ".zshrc".source = "${dot-local}/zsh/zshrc";
        ".zprofile".source = "${dot-local}/zsh/zprofile";
        ".gitconfig".source = "${dot-local}/git/gitconfig";
        ".config/starship.toml".source = "${dot-local}/starship/starship.toml";
        ".config/doom/config.el".source = "${dot-local}/doom/config.el";
        ".config/doom/init.el".source = "${dot-local}/doom/init.el";
        ".config/doom/packages.el".source = "${dot-local}/doom/packages.el";
      };
    };

    mkDarwinConfig = { username ? "taude", hostPlatform ? "aarch64-darwin" }:
      nix-darwin.lib.darwinSystem {
        modules = [
          (mkConfiguration { inherit username hostPlatform; })
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.${username} = mkHomeManagerConfiguration { inherit username; };
          }
        ];
      };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#simple
    darwinConfigurations."Todds-MacBook-Neo" = mkDarwinConfig { };

    # Placeholder configs for two more machines. Before using either one:
    #   1. Rename the attribute below (e.g. "CHANGEME-mac-mini") to the
    #      machine's real hostname — run `scutil --get LocalHostName` on
    #      that Mac to find it.
    #   2. If the macOS account name on that machine isn't "taude", pass
    #      `username = "whatever";` below.
    #   3. If it's an Intel Mac, pass `hostPlatform = "x86_64-darwin";`.
    # See README.md for the full walkthrough.
    darwinConfigurations."CHANGEME-mac-mini" = mkDarwinConfig { };
    darwinConfigurations."CHANGEME-work-computer" = mkDarwinConfig { };
  };
}
