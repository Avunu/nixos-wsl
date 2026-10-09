{
  description = "NixOS WSL Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    attic = {
      url = "github:zhaofengli/attic";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Pre-commit hooks, run by `nix flake check` and installed by the devShell.
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      attic,
      nixpkgs,
      nixos-wsl,
      vscode-server,
      git-hooks,
      ...
    }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosModules.wsl =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        with lib;
        let
          cfg = config.wslHost;

          # `--impure` is what the old autoUpgrade and README rebuilds passed.
          systemUpgrade = import ./pkgs/system-upgrade.nix {
            inherit pkgs;
            extraFlags = "--impure";
          };
        in
        {
          imports = [
            inputs.nixos-wsl.nixosModules.default
            inputs.vscode-server.nixosModules.default
          ];

          options.wslHost = {
            defaultUser = mkOption {
              type = types.str;
              default = "nixos";
              description = "Default WSL user";
            };
            sshKeys = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "SSH public keys for the default user";
            };
            stateVersion = mkOption {
              type = types.str;
              default = "24.11";
              description = "NixOS state version";
            };
            extraPackages = mkOption {
              type = types.listOf types.package;
              default = [ ];
              description = "Additional packages to install";
            };
            vscodeIntegration = mkOption {
              type = types.bool;
              default = true;
              description = "Enable VS Code Server integration";
            };
            dockerIntegration = mkOption {
              type = types.bool;
              default = false;
              description = "Enable Docker Desktop integration";
            };
            atticIntegration = mkOption {
              type = types.bool;
              default = false;
              description = "Enable Attic binary cache client";
            };
            ccache = mkOption {
              type = types.bool;
              default = true;
              description = "Enable ccache compiler cache";
            };
            emulatedSystems = mkOption {
              type = types.listOf types.str;
              default = [ "aarch64-linux" ];
              description = "Systems to emulate via binfmt (passed through to boot.binfmt.emulatedSystems)";
            };
          };

          config = {
            wsl = {
              enable = true;
              defaultUser = cfg.defaultUser;
              docker-desktop.enable = cfg.dockerIntegration;
              startMenuLaunchers = true;
              useWindowsDriver = true;
            };

            environment = {
              systemPackages =
                with pkgs;
                lib.flatten [
                  (pkgs.writeShellApplication {
                    name = "devsh";
                    runtimeInputs = with pkgs; [
                      nix
                    ];
                    text = ''
                      nix develop --no-pure-eval
                    '';
                  })
                  (python3.withPackages (
                    python-pkgs: with python-pkgs; [
                      black
                      flake8
                      isort
                      pandas
                      requests
                    ]
                  ))
                  [
                    bun
                    cmake
                    curl
                    gh
                    git
                    gnumake
                    nano
                    nixfmt
                    nixos-container
                    nixpkgs-fmt
                    nodejs_latest
                    tzdata
                    wget
                  ]
                  (lib.optional cfg.ccache pkgs.ccache)
                  (lib.optional cfg.atticIntegration attic.packages.${pkgs.system}.attic)
                  systemUpgrade
                  cfg.extraPackages
                ];
            };

            hardware.graphics = {
              enable = true;
              extraPackages = with pkgs; [ mesa ];
            };

            nix.settings = {
              experimental-features = [
                "nix-command"
                "flakes"
              ];
              extra-sandbox-paths = lib.mkIf cfg.ccache [ "/var/cache/ccache" ];
              substituters = lib.flatten [
                [
                  "https://cache.nixos.org?priority=40"
                  "https://nix-community.cachix.org?priority=41"
                  "https://numtide.cachix.org?priority=42"
                ]
                (lib.optional cfg.atticIntegration "https://attic.batonac.com/k3s?priority=43")
              ];
              trusted-public-keys = lib.flatten [
                [
                  "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                  "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
                ]
                (lib.optional cfg.atticIntegration "k3s:A8GYNJNy2p/ZMtxVlKuy1nZ8bnZ84PVfqPO6kg6A6qY=")
              ];
              trusted-users = [
                "root"
                cfg.defaultUser
                "@wheel"
              ];
            };

            programs = {
              ccache = lib.mkIf cfg.ccache {
                cacheDir = "/var/cache/ccache";
                enable = true;
              };
              direnv = {
                enable = true;
                angrr = {
                  autoUse = true;
                  enable = true;
                };
                nix-direnv.enable = true;
                enableBashIntegration = true;
              };
              git = {
                enable = true;
                config.safe.directory = [
                  "/etc/nixos"
                  "/home/${cfg.defaultUser}/"
                ];
              };
              nix-ld = {
                enable = mkDefault true;
                package = pkgs.nix-ld;
                libraries = with pkgs; [
                  alsa-lib
                  glib
                  json-glib
                  libxkbcommon
                  openssl
                  vulkan-loader
                  vulkan-validation-layers
                  wayland
                  zstd
                ];
              };
            };

            security.sudo = {
              enable = true;
              wheelNeedsPassword = false;
            };

            services = {
              openssh.enable = true;
              vscode-server.enable = lib.mkIf cfg.vscodeIntegration true;
              logrotate.checkConfig = false;
            };

            # The daily upgrade runs `system-upgrade`, which rebuilds only when
            # the lock moved. NixOS's own system.autoUpgrade stays off, as in
            # nixos-dev-host: it rebuilds every day whether or not anything did.
            # It never reboots.
            system.stateVersion = cfg.stateVersion;

            systemd.services.system-upgrade = {
              restartIfChanged = false;
              unitConfig = {
                Description = "Upgrade NixOS from /etc/nixos";
                StartLimitIntervalSec = 300;
                StartLimitBurst = 5;
              };
              serviceConfig = {
                Type = "oneshot";
                User = "root";
                Environment = "HOME=/root";
                ExecStart = getExe systemUpgrade;
                Restart = "on-failure";
                RestartSec = "120s";
                # A full flake evaluation and rebuild, unattended, while someone
                # may be using the machine. It should be the process that yields.
                MemoryHigh = mkDefault "25%";
                CPUWeight = mkDefault 20;
                Nice = mkDefault 19;
              };
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              path = [
                pkgs.git
                pkgs.nix
              ];
            };

            systemd.timers.system-upgrade = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = "daily";
                Persistent = true;
                Unit = "system-upgrade.service";
              };
            };

            boot.binfmt.emulatedSystems = cfg.emulatedSystems;

            users.users.${cfg.defaultUser} = {
              extraGroups = lib.flatten [
                [ "wheel" ]
                (lib.optional cfg.dockerIntegration "docker")
              ];
              isNormalUser = true;
              openssh.authorizedKeys.keys = cfg.sshKeys;
              shell = pkgs.bash;
            };
          };
        };

      packages.${system}.system-upgrade = import ./pkgs/system-upgrade.nix {
        inherit pkgs;
        extraFlags = "--impure";
      };

      formatter.${system} = pkgs.nixfmt;

      # A configuration that exists only to be evaluated, as in nixos-dev-host:
      # the eval check forces every option merge, assertion and warning in the
      # module, so an error shows up here rather than on a machine.
      nixosConfigurations.example = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.wsl
          { wslHost.defaultUser = "example"; }
        ];
      };

      checks.${system} = {
        eval = pkgs.runCommand "wsl-eval-check" { } ''
          echo "${builtins.unsafeDiscardStringContext self.nixosConfigurations.example.config.system.build.toplevel.drvPath}" > "$out"
        '';

        pre-commit = git-hooks.lib.${system}.run {
          src = ./.;
          hooks.nixfmt = {
            enable = true;
            package = pkgs.nixfmt;
          };
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.nixfmt
          pkgs.prek
        ];
        inherit (self.checks.${system}.pre-commit) shellHook;
      };
    };
}
