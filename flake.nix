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
    {
      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [

            nixos-wsl.nixosModules.default

            vscode-server.nixosModules.default

            (
              { pkgs, lib, ... }:
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

                environment.systemPackages = with pkgs; [
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
                  wget
                  yarn
                  attic.packages.${pkgs.system}.attic
                ];

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
                };

                programs = {
                  ccache = {
                    cacheDir = "/var/cache/ccache";
                    enable = true;
                  };
                  direnv.enable = true;
                  nix-ld = {
                    enable = true;
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
                    package = pkgs.nix-ld-rs;
                  };
                  virt-manager.enable = true;
                };

                services.vscode-server.enable = true;

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
                    ];
                  };
                };

                users = {
                  users.nixos = {
                    isNormalUser = true;
                    extraGroups = [
                      "libvirtd"
                      "nixbld"
                      "wheel"
                    ];
                    shell = pkgs.bashInteractive;
                  };
                };

                virtualisation = {
                  libvirtd = {
                    enable = true;
                    qemu.ovmf.enable = true;
                    nss.enableGuest = true;
                  };
                  # podman = {
                  #   enable = true;
                  #   dockerSocket.enable = true;
                  #   dockerCompat = true;
                  # };
                };

                wsl = {
                  enable = true;
                  defaultUser = "nixos";
                  extraBin = with pkgs; [
                    { src = "${uutils-coreutils-noprefix}/bin/cat"; }
                    { src = "${uutils-coreutils-noprefix}/bin/whoami"; }
                    { src = "${busybox}/bin/addgroup"; }
                    { src = "${su}/bin/groupadd"; }
                  ];
                  nativeSystemd = true;
                };
              }
            )
          ];
        };
      };
    };
}
