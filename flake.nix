{
  description = "MCP server and CLI tool for controlling Neovim in tmux sessions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      # Node.js package for the MCP server
      mcpnvimtmux = pkgs.buildNpmPackage rec {
        pname = "mcpnvimtmux";
        version = "1.0.0";

        src = ./.;

        npmDepsHash = "sha256-K1M5lkN1tZN6qHhv1dm8c1CpeGOxk268jwHL+xq1n+Q=";

        # Don't run npm build since this is a runtime script
        dontNpmBuild = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/lib/mcpnvimtmux
          cp -r node_modules package.json package-lock.json index.js $out/lib/mcpnvimtmux/

          # Create wrapper script
          mkdir -p $out/bin
          makeWrapper ${pkgs.nodejs_20}/bin/node $out/bin/mcpnvimtmux \
            --add-flags "$out/lib/mcpnvimtmux/index.js"

          runHook postInstall
        '';
      };

      # Bash script
      nvimrun = pkgs.writeScriptBin "nvimrun" ''
        #!${pkgs.bash}/bin/bash
        exec ${pkgs.bash}/bin/bash ${./nvimrun.sh} "$@"
      '';
    in {
      # Packages that can be built
      packages = {
        default = mcpnvimtmux;
        inherit mcpnvimtmux nvimrun;
      };

      # Development shell
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nodejs_20
          tmux
          neovim
          bash
        ];

        shellHook = ''
          echo "Development environment for @aetherall/mcp-nvim-tmux"
          echo ""
          echo "Available commands:"
          echo "  npm install    - Install dependencies"
          echo "  npm start      - Start MCP server"
          echo "  ./nvimrun.sh   - Run nvimrun directly"
          echo ""
        '';
      };

      # Apps that can be run with `nix run`
      apps = {
        default = flake-utils.lib.mkApp {
          drv = mcpnvimtmux;
        };

        nvimrun = flake-utils.lib.mkApp {
          drv = nvimrun;
        };

        mcpnvimtmux = flake-utils.lib.mkApp {
          drv = mcpnvimtmux;
        };
      };
    });
}
