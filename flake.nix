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
      lib = {
        getVirt =
          { config, lib, ... }:
          let
            # Read kernel release info
            kernelRelease = builtins.readFile "/proc/sys/kernel/osrelease";

            # Check WSL indicators
            wslPaths = [
              "/proc/sys/fs/binfmt_misc/WSLInterop"
              "/run/WSL"
            ];
            hasWSLPaths = builtins.any (p: builtins.pathExists p) wslPaths;
            isWSLKernel =
              lib.strings.hasInfix "microsoft" (lib.strings.toLower kernelRelease)
              || lib.strings.hasInfix "WSL" kernelRelease;

            # Check Hyper-V indicators
            dmiFile = "/sys/devices/virtual/dmi/id/bios_version";
            dmiContent = if builtins.pathExists dmiFile then builtins.readFile dmiFile else "";
            isHyperV = lib.strings.hasInfix "Hyper-V" dmiContent;

          in
          if hasWSLPaths || isWSLKernel then
            "wsl"
          else if isHyperV then
            "microsoft"
          else
            "none";

        isWSL = { config, lib, ... }: (self.lib.getVirt { inherit config lib; }) == "wsl";

        isHyperV = { config, lib, ... }: (self.lib.getVirt { inherit config lib; }) == "microsoft";
      };

      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [

            nixos-wsl.nixosModules.default

            vscode-server.nixosModules.default

            (
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
                      "docker"
                      "libvirtd"
                      "nixbld"
                      "wheel"
                    ];
                    shell = pkgs.bashInteractive;
                  };
                };

                # WSL-specific configuration
                wsl = lib.mkIf (self.lib.isWSL { inherit config lib; }) {
                  enable = true;
                  defaultUser = "nixos";
                  docker-desktop.enable = true;
                  nativeSystemd = true;
                  startMenuLaunchers = true;
                  useWindowsDriver = true;
                };

                # HyperV-specific configuration
                virtualisation = lib.mkIf (self.lib.isHyperV { inherit config lib; }) {
                  hypervGuest = {
                    enable = true;
                    videoMode = "1920x1080";
                  };
                };

                # Optional: HyperV-specific networking
                networking = lib.mkIf (self.lib.isHyperV { inherit config lib; }) {
                  useDHCP = true; # Or configure static IP if needed
                  # Enable specific network interfaces if needed
                  interfaces = {
                    eth0.useDHCP = true;
                  };
                };
              }
            )
          ];
        };
      };
    };
}
