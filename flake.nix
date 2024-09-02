# start the nix shell and start vscode in it
# nix flake init
# nix develop
# code .

{
  description = "Flake for mysticeti project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs { inherit system; overlays = [ rust-overlay.overlay ]; };
        rustToolchain = pkgs.rust-bin.stable.latest.default;
        rustPlatform = pkgs.makeRustPlatform { rustc = rustToolchain; cargo = rustToolchain; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rustToolchain
            rustPlatform.rustc
            rustPlatform.cargo
            openssl
            pkg-config
            clang
          ];

          shellHook = ''
            export RUST_BACKTRACE=1
            export CARGO_INCREMENTAL=0
          '';
        };
      }
    );
}
