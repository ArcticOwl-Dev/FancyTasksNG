{
  description = "FancyTasksNG packages, development tools and isolated Plasma preview";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
      baseVersion = (builtins.fromJSON (builtins.readFile ./package/metadata.json)).KPlugin.Version;
      packageVersion = "${baseVersion}-${self.shortRev or self.dirtyShortRev or "source"}";
      toolsFor =
        pkgs: with pkgs; [
          bashInteractive
          coreutils
          diffutils
          findutils
          gettext
          git
          gnumake
          gnugrep
          gnused
          nodejs
          (python3.withPackages (ps: [ ps.dbus-python ps.pygobject3 ]))
          zip
          unzip
        ];
      previewFor =
        pkgs:
        pkgs.writeShellApplication {
          name = "fancytasks-preview";
          runtimeInputs = toolsFor pkgs;
          text = ''
            if [[ ! -f tools/preview.sh || ! -f package/metadata.json ]]; then
              echo "Run fancytasks-preview from the FancyTasksNG repository root." >&2
              exit 1
            fi
            export FANCYTASKS_NATIVE_DIR=${self.packages.${pkgs.stdenv.hostPlatform.system}.native-support}/lib/fancytasksng/native
            exec bash tools/preview.sh
          '';
        };
    in
    {
      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          nativeSupport = pkgs.callPackage ./nix/native.nix {
            src = pkgs.lib.cleanSourceWith {
              src = self;
              name = "source";
              filter = path: type:
                let relative = pkgs.lib.removePrefix "${self}/" path;
                in type == "directory" || pkgs.lib.hasPrefix "native/" relative
                  || relative == "package/contents/ui/ZoomHitTarget.qml";
            };
          };
          buildPlasmoid =
            testWidget:
            pkgs.callPackage ./nix/plasmoid.nix {
              src = self;
              version = packageVersion;
              inherit nativeSupport;
              inherit testWidget;
            };
          plasmoid = buildPlasmoid false;
        in
        {
          inherit plasmoid;
          native-support = nativeSupport;
          default = plasmoid;
          plasmoid-test = buildPlasmoid true;
        }
      );

      devShells = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = toolsFor pkgs ++ [ (previewFor pkgs) ];
            FANCYTASKS_NATIVE_DIR = "${self.packages.${system}.native-support}/lib/fancytasksng/native";
          };
        }
      );

      apps = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          installDev = pkgs.callPackage ./nix/install-dev.nix {
            plasmoid = self.packages.${system}.plasmoid-test;
          };
        in
        {
          preview = {
            type = "app";
            program = "${previewFor pkgs}/bin/fancytasks-preview";
          };
          install-dev = {
            type = "app";
            program = "${installDev}/bin/fancytasks-install-dev";
          };
        }
      );

      checks = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          native-support = self.packages.${system}.native-support;
          preview-runtime = pkgs.runCommand "fancytasks-preview-runtime-check"
            { nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.dbus-python ps.pygobject3 ])) ]; }
            ''
              python3 -c 'import dbus; from dbus.mainloop.glib import DBusGMainLoop; from gi.repository import GLib'
              touch "$out"
            '';
          rules =
            pkgs.runCommand "fancytasks-checks"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.nodejs
                  pkgs.python3
                ];
              }
              ''
                cd ${self}
                node tools/test_app_rules.cjs
                node tools/test_position_order.cjs
                node tools/test_task_indexes.cjs
                node tools/test_title_policy.cjs
                node tools/test_python_runtime.cjs
                python3 tools/sync_defaults.py --check
                for script in tools/*.sh; do
                  bash -n "$script"
                done
                touch "$out"
              '';
        }
      );
    };
}
