{
  description = "xs-user PWA build and layered Docker image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        fn:
        nixpkgs.lib.genAttrs systems (
          system:
          fn {
            inherit system;
            pkgs = import nixpkgs { inherit system; };
          }
        );
    in
    {
      packages = forAllSystems (
        { pkgs, ... }:
        let
          src = builtins.path {
            path = ./.;
            name = "xs-user-src";
            filter =
              path: type:
              let
                relPath = pkgs.lib.removePrefix "${toString ./.}/" (toString path);
                isGit = relPath == ".git" || pkgs.lib.hasPrefix ".git/" relPath;
                isBuild = relPath == "build" || pkgs.lib.hasPrefix "build/" relPath;
                isDartTool =
                  relPath == ".dart_tool" || pkgs.lib.hasPrefix ".dart_tool/" relPath;
                isIdea = relPath == ".idea" || pkgs.lib.hasPrefix ".idea/" relPath;
              in
              !(isGit || isBuild || isDartTool || isIdea);
          };

          pubspecLock = pkgs.lib.importJSON (
            pkgs.runCommand "pubspec.lock.json" { nativeBuildInputs = [ pkgs.yq-go ]; } ''
              yq -o=json '.' ${src}/pubspec.lock > "$out"
            ''
          );

          dartDefineKeys = [
            "API_BASE_URL"
            "SERVER_CLIENT_ID"
            "ALLOWED_GOOGLE_DOMAINS"
            "FIREBASE_WEB_API_KEY"
            "FIREBASE_WEB_APP_ID"
            "FIREBASE_WEB_MESSAGING_SENDER_ID"
            "FIREBASE_WEB_PROJECT_ID"
            "FIREBASE_WEB_AUTH_DOMAIN"
            "FIREBASE_WEB_STORAGE_BUCKET"
            "FIREBASE_WEB_MEASUREMENT_ID"
          ];

          dartDefineFlags = builtins.concatLists (
            builtins.map
              (
                key:
                let
                  value = builtins.getEnv key;
                in
                if value == "" then [ ] else [ "--dart-define=${key}=${value}" ]
              )
              dartDefineKeys
          );

          webBuild = pkgs.flutter.buildFlutterApplication {
            pname = "xs-user-web";
            version = "1.0.0";
            inherit src pubspecLock;
            targetFlutterPlatform = "web";
            flutterBuildFlags = [ "--base-href=/app/" ] ++ dartDefineFlags;
            postPatch = ''
              if [ ! -f .env ]; then
                touch .env
              fi
            '';
          };

          siteRoot = pkgs.runCommand "xs-user-site-root" { } ''
            mkdir -p "$out/srv/app" "$out/srv/install"
            cp -r ${webBuild}/* "$out/srv/app/"
            cp -r ${src}/deploy/install/* "$out/srv/install/"
            cp ${src}/deploy/caddy/Caddyfile "$out/Caddyfile"
          '';

          dockerImage = pkgs.dockerTools.buildLayeredImage {
            name = "xs-user-pwa";
            tag = "latest";
            contents = [
              pkgs.caddy
              siteRoot
            ];
            config = {
              Cmd = [
                "caddy"
                "run"
                "--config"
                "/Caddyfile"
                "--adapter"
                "caddyfile"
              ];
              ExposedPorts = {
                "8080/tcp" = { };
              };
            };
          };
        in
        {
          web = webBuild;
          image = dockerImage;
          dockerImage = dockerImage;
          default = dockerImage;
        }
      );

      apps = forAllSystems (
        { pkgs, system }:
        {
          build-web = {
            type = "app";
            program = "${pkgs.writeShellScript "build-web" ''
              set -euo pipefail
              exec nix build .#packages.${system}.web "$@"
            ''}";
          };
          build-image = {
            type = "app";
            program = "${pkgs.writeShellScript "build-image" ''
              set -euo pipefail
              exec nix build .#packages.${system}.dockerImage "$@"
            ''}";
          };
        }
      );

      devShells = forAllSystems (
        { pkgs, ... }:
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.flutter
              pkgs.yq-go
              pkgs.caddy
            ];
          };
        }
      );
    };
}
