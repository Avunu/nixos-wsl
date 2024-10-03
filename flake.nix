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
                  curl
                  git
                  nano
                  nixfmt-rfc-style
                  nixos-container
                  nixpkgs-fmt
                  nodejs_22
                  nodePackages.wrangler
                  pnpm
                  wget
                  yarn
                  attic.packages.${pkgs.system}.attic
                ];

                nix.settings = {
                  experimental-features = [
                    "nix-command"
                    "flakes"
                  ];
                  substituters = [
                    "https://attic.batonac.com/k3s"
                  ];
                  trusted-public-keys = [
                    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                    "k3s:A8GYNJNy2p/ZMtxVlKuy1nZ8bnZ84PVfqPO6kg6A6qY="
                  ];
                };

                programs.nix-ld = {
                  enable = true;
                  package = pkgs.nix-ld-rs;
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
                      "-L" # print build logs
                    ];
                  };
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
                };
              }
            )
          ];
        };
      };
    };
}
