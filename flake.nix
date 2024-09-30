{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
  };

  outputs = { self, nixpkgs, nixos-wsl, vscode-server, ... }: {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixos-wsl.nixosModules.default
          vscode-server.nixosModules.default
          {
            environment.systemPackages = with pkgs; [
                bun
                curl
                git
                nano
                nixfmt-rfc-style
                nodejs_22
                nodePackages.wrangler
                pnpm
                wget
                yarn
            ];
            programs.nix-ld = {
                enable = true;
                package = pkgs.nix-ld-rs;
            };
            services.vscode-server.enable = true;
            system.stateVersion = "24.05";
            wsl = {
              enable = true;
              defaultUser = "nixos";
              extraBin = with pkgs; [
                {src = "${uutils-coreutils-noprefix}/bin/cat";}
                {src = "${uutils-coreutils-noprefix}/bin/whoami";}
                {src = "${busybox}/bin/addgroup";}
                {src = "${su}/bin/groupadd";}
              ];
            };
          }
        ];
      };
    };
  };
}
