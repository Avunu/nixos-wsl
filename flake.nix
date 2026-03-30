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
  };

  outputs =
    inputs@{
      self,
      attic,
      nixpkgs,
      nixos-wsl,
      vscode-server,
      ...
    }:
    let
      lib = nixpkgs.lib;
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
                  (writeShellScriptBin "system-upgrade" ''
                    sudo sh -c 'cd /etc/nixos && nix flake update && nixos-rebuild switch --impure'
                  '')
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

            system = {
              stateVersion = cfg.stateVersion;
              autoUpgrade = {
                enable = true;
                allowReboot = false;
                dates = "daily";
                flake = "/etc/nixos/flake.nix";
                flags = [
                  "--update-input"
                  "nixpkgs"
                  "--update-input"
                  "nixos-wsl-host"
                  "--refresh"
                  "--impure"
                ];
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
    };
}
