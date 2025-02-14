{
  inputs = {
    attic.url = "github:zhaofengli/attic";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
    {
      self,
      attic,
      nixpkgs,
      nixos-wsl,
      vscode-server,
      ...
    }:
    let
      isWSL = builtins.pathExists /usr/lib/wsl/lib;

      # WSL-specific module
      wslModule =
        { config, lib, ... }:
        {
          wsl = {
            enable = true;
            defaultUser = "nixos";
            docker-desktop.enable = true;
            startMenuLaunchers = true;
            useWindowsDriver = true;
          };
        };

      # HyperV-specific module
      hypervModule =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        {
          boot = {
            extraModulePackages = [ ];
            initrd = {
              availableKernelModules = [
                "sd_mod"
                "sr_mod"
              ];
              kernelModules = [ ];
            };
            kernelModules = [ ];
            kernelPackages = pkgs.linuxPackages_latest;
            loader = {
              systemd-boot.enable = true;
              efi.canTouchEfiVariables = true;
            };
          };

          environment = {
            systemPackages = with pkgs; [
              docker-compose
              podman-compose
              podman-tui
            ];
          };

          fileSystems = {
            "/" = {
              device = "/dev/disk/by-partlabel/root";
              fsType = "btrfs";
              options = [ "subvol=@" ];
            };

            "/boot" = {
              device = "/dev/disk/by-partlabel/EFI";
              fsType = "vfat";
              options = [
                "fmask=0077"
                "dmask=0077"
              ];
            };
          };

          virtualisation = {
            containers.storage.settings = {
              storage = {
                driver = "btrfs";
                graphroot = "/var/lib/containers/storage";
                runroot = "/run/containers/storage";
              };
            };
            hypervGuest = {
              enable = true;
              videoMode = "1920x1080";
            };
            oci-containers.backend = "podman";
            podman = {
              autoPrune.enable = true;
              defaultNetwork.settings = {
                dns_enabled = true;
              };
              dockerCompat = true;
              dockerSocket.enable = true;
              enable = true;
            };
          };

          networking = {
            useDHCP = true;
            interfaces = {
              eth0.useDHCP = true;
            };
          };
        };

      # Common configuration module
      commonModule =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        let
          pythonPackages = pkgs.python3.withPackages (
            python-pkgs: with python-pkgs; [
              black
              flake8
              isort
              pandas
              requests
            ]
          );
        in
        {
          environment = {
            systemPackages = with pkgs; [
              attic.packages.${pkgs.system}.attic
              bun
              ccache
              cmake
              curl
              gh
              git
              gnumake
              nano
              nixfmt-rfc-style
              nixos-container
              nixpkgs-fmt
              nodejs_22
              pnpm
              pythonPackages
              tzdata
              wget
              yarn
              zed-editor
            ];
          };

          hardware.graphics = {
            enable = true;
            extraPackages = with pkgs; [
              mesa.drivers
              libvdpau-va-gl
              vaapiVdpau
            ];
          };

          nix.settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];
            extra-sandbox-paths = [ "/var/cache/ccache" ];
            substituters = [
              "https://cache.nixos.org?priority=40"
              "https://nix-community.cachix.org?priority=41"
              "https://numtide.cachix.org?priority=42"
              "https://attic.batonac.com/k3s?priority=43"
            ];
            trusted-public-keys = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
              "k3s:A8GYNJNy2p/ZMtxVlKuy1nZ8bnZ84PVfqPO6kg6A6qY="
            ];
            trusted-users = [
              "root"
              "nixos"
              "@wheel"
            ];
          };

          programs = {
            ccache = {
              cacheDir = "/var/cache/ccache";
              enable = true;
            };
            direnv.enable = true;
            nix-ld.enable = true;
          };

          security.sudo = {
            enable = true;
            wheelNeedsPassword = false;
          };

          services = {
            openssh.enable = true;
            vscode-server.enable = true;
            logrotate.checkConfig = false;
          };

          system = {
            stateVersion = "24.11";
            autoUpgrade = {
              enable = true;
              allowReboot = false;
              dates = "daily";
              flake = "github:Avunu/nixos-wsl";
              flags = [
                "--update-input"
                "nixpkgs"
                "--refresh"
                "--impure"
              ];
            };
          };

          users = {
            users.nixos = {
              extraGroups = [
                "docker"
                "libvirtd"
                "nixbld"
                "wheel"
              ];
              isNormalUser = true;
              openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOv4SpIhHJqtRaYBRQOin4PTDUxRwo7ozoQHTUFjMGLW avunu@AvunuCentral"
              ];
              shell = pkgs.bash;
            };
          };
        };
    in
    {
      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nixos-wsl.nixosModules.default
            vscode-server.nixosModules.default
            commonModule
            (
              {
                config,
                pkgs,
                lib,
                ...
              }:
              {
                config = lib.mkMerge [
                  (lib.mkIf isWSL (wslModule {
                    inherit config pkgs lib;
                  }))
                  (lib.mkIf (!isWSL) (hypervModule {
                    inherit config pkgs lib;
                  }))
                ];
              }
            )
          ];
        };
      };
    };
}
