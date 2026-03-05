{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl-host = {
      url = "github:Avunu/nixos-wsl";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-wsl-host,
    }:
    {
      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            { nix.nixPath = [ "nixpkgs=${self.inputs.nixpkgs}" ]; }
            nixos-wsl-host.nixosModules.wsl
            {
              wslHost = {
                defaultUser = "nixos";
                stateVersion = "24.11";
                sshKeys = [
                  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOv4SpIhHJqtRaYBRQOin4PTDUxRwo7ozoQHTUFjMGLW avunu@AvunuCentral"
                ];
                vscodeIntegration = true;
                dockerIntegration = false;
                atticIntegration = true;
                ccache = true;
                extraPackages = [ ];
              };
            }
          ];
        };
      };
    };
}
