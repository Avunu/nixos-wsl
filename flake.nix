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

                environment = {
                  sessionVariables = {
                    LD_LIBRARY_PATH = [
                      "/usr/lib/wsl/lib"
                      "${pkgs.ncurses5}/lib"
                      "/run/opengl-driver/lib"
                    ];
                  };
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

                systemd.sleep.extraConfig = ''
                  AllowHibernation=no
                  AllowHybridSleep=no
                  AllowSuspend=no
                  AllowSuspendThenHibernate=no
                '';

                users = {
                  users.nixos = {
                    isNormalUser = true;
                    extraGroups = [
                      "docker"
                      "libvirtd"
                      "nixbld"
                      "wheel"
                    ];
                    shell = pkgs.bashInteractive;
                  };
                };

                # virtualisation = {
                #   libvirtd = {
                #     enable = true;
                #     qemu.ovmf.enable = true;
                #     nss.enableGuest = true;
                #   };
                # };

                wsl = {
                  enable = true;
                  defaultUser = "nixos";
                  docker-desktop.enable = true;
                  nativeSystemd = true;
                  startMenuLaunchers = true;
                  useWindowsDriver = true;
                };
              }
            )
          ];
        };
      };
    };
}
