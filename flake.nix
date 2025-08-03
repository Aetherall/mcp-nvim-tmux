{
  description = "MCP server and CLI tool for controlling Neovim in tmux sessions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Node.js package for the MCP server
        mcpnvimtmux = pkgs.stdenv.mkDerivation rec {
          pname = "mcpnvimtmux";
          version = "1.0.0";
          
          src = ./.;
          
          nativeBuildInputs = with pkgs; [ nodejs_20 makeWrapper ];
          
          buildPhase = ''
            # Copy package files
            cp -r $src/* .
            
            # Install npm dependencies
            export HOME=$TMPDIR
            npm ci --production
          '';
          
          installPhase = ''
            mkdir -p $out/lib/mcpnvimtmux
            cp -r node_modules package.json package-lock.json index.js $out/lib/mcpnvimtmux/
            
            # Create wrapper script
            mkdir -p $out/bin
            makeWrapper ${pkgs.nodejs_20}/bin/node $out/bin/mcpnvimtmux \
              --add-flags "$out/lib/mcpnvimtmux/index.js"
          '';
        };
        
        # Bash script
        nvimrun = pkgs.writeScriptBin "nvimrun" ''
          #!${pkgs.bash}/bin/bash
          exec ${pkgs.bash}/bin/bash ${./nvimrun.sh} "$@"
        '';
        
      in
      {
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