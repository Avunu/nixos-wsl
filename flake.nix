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
            nativeSystemd = true;
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
              dockerCompat = true;
              dockerSocket.enable = true;
              enable = true;
              networkSocket.enable = true;
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
              bun
              ccache
              curl
              git
              nano
              nixfmt-rfc-style
              nixos-container
              nixpkgs-fmt
              nodejs_22
              nodePackages.wrangler
              pnpm
              pythonPackages
              tzdata
              wget
              yarn
              zed-editor
              attic.packages.${pkgs.system}.attic
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
              "https://attic.batonac.com/k3s"
            ];
            trusted-public-keys = [
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

          services = {
            openssh.enable = true;
            vscode-server.enable = true;
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
              shell = pkgs.bashInteractive;
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
            (lib.mkIf isWSL wslModule)
            (lib.mkIf (!isWSL) hypervModule)
          ];
        };
      };
    };
}
