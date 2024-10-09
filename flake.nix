{
  inputs = {
    attic.url = "github:zhaofengli/attic";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
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
              { pkgs, ... }:
              {

                environment.systemPackages = with pkgs; [
                  bun
                  ccache
                  curl
                  git
                  # guestfs-tools
                  libguestfs-with-appliance
                  nano
                  nixfmt-rfc-style
                  nixos-container
                  nixpkgs-fmt
                  nodejs_22
                  nodePackages.wrangler
                  OVMF
                  pnpm
                  qemu
                  sparse
                  virt-manager
                  wget
                  yarn
                  zed-editor
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
                  # nix-ld = {
                  #   enable = true;
                  #   libraries = with pkgs; [
                  #     alsa-lib
                  #     glib
                  #     json-glib
                  #     libxkbcommon
                  #     openssl
                  #     vulkan-loader
                  #     vulkan-validation-layers
                  #     wayland
                  #     zstd
                  #   ];
                  #   package = pkgs.nix-ld-rs;
                  # };
                  virt-manager.enable = true;
                };

                services.vscode-server.enable = true;

                system = {
                  stateVersion = "24.05";
                  autoUpgrade = {
                    enable = true;
                    allowReboot = false;
                    dates = "daily";
                    flake = "github:Avunu/nixos-wsl";
                    flags = [
                      "--update-input"
                      "nixpkgs"
                    ];
                  };
                };

                users = {
                  defaultUserShell = pkgs.bashInteractive;
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

                virtualisation.libvirtd.enable = true;

                wsl = {
                  enable = true;
                  defaultUser = "nixos";
                  extraBin = with pkgs; [
                    { src = "${uutils-coreutils-noprefix}/bin/cat"; }
                    { src = "${uutils-coreutils-noprefix}/bin/whoami"; }
                    { src = "${busybox}/bin/addgroup"; }
                    { src = "${su}/bin/groupadd"; }
                  ];
                };
              }
            )
          ];
        };
      };
    };
}
