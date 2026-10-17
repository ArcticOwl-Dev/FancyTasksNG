{
  lib,
  stdenvNoCC,
  python3,
  dbus,
  gettext,
  zip,
  src,
  version,
  nativeSupport,
  testWidget ? false,
}:
let
  archiveName = if testWidget then "FancyTasksNG-M1-Test.plasmoid" else "FancyTasksNG.plasmoid";
  pythonRuntime = python3.withPackages (ps: [ ps.dbus-python ps.pygobject3 ]);
in
stdenvNoCC.mkDerivation {
  pname = if testWidget then "fancytasksng-m1-test" else "fancytasksng";
  inherit src version;

  nativeBuildInputs = [
    python3
    gettext
    zip
  ];
  strictDeps = true;
  TZ = "UTC";

  postPatch = ''
    patchShebangs --build tools/compile_messages.sh
  '';

  buildPhase = ''
    runHook preBuild
    python3 tools/sync_defaults.py --check
    # Package committed translations without refreshing timestamped PO headers.
    ./tools/compile_messages.sh
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -R package staging
    substituteInPlace staging/contents/ui/code/PythonRuntime.js \
      --replace-fail 'const executable = "python3";' 'const executable = "${pythonRuntime}/bin/python3";'
    cp -R ${nativeSupport}/lib/fancytasksng/native staging/contents/ui/native
    chmod -R u+w staging/contents/ui/native
    export PLASMOID_TEST_WIDGET=${if testWidget then "1" else "0"}
    python3 - <<'PY'
    import json
    import os
    from pathlib import Path

    path = Path("staging/metadata.json")
    metadata = json.loads(path.read_text())
    plugin = metadata["KPlugin"]
    plugin["Version"] = os.environ["version"]
    if os.environ["PLASMOID_TEST_WIDGET"] == "1":
        plugin["Id"] = "io.github.daydve.fancytasksng.m1test"
        plugin["Name"] = "Fancy Tasks NG (Dev)"
        for key in list(plugin):
            if key.startswith("Name["):
                del plugin[key]
    path.write_text(json.dumps(metadata, indent=4) + "\n")
    PY
    # Stable file ordering, ZIP timestamps and extra fields make rebuilding
    # identical source independent of the checkout and build time.
    find staging -type f -exec touch -d '@315532800' {} +
    mkdir -p "$out"
    # ZIP compression hides store references from Nix's reference scanner.
    # Keep the runtime (and native module dependencies) in the package closure.
    mkdir -p "$out/nix-support"
    printf '%s\n' '${pythonRuntime}' '${nativeSupport}' > "$out/nix-support/runtime-dependencies"
    (cd staging; find . -type f -printf '%P\n' | LC_ALL=C sort | zip -X -q "$out/${archiveName}" -@)
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ dbus ];
  installCheckPhase = ''
    runHook preInstallCheck
    grep -F '${pythonRuntime}/bin/python3' staging/contents/ui/code/PythonRuntime.js
    dbus-run-session --config-file=${dbus}/share/dbus-1/session.conf -- \
      ${pythonRuntime}/bin/python3 tools/test_config_io.py staging/contents/ui/code/desktop_actions.py
    runHook postInstallCheck
  '';

  meta = {
    description = "Installable FancyTasksNG Plasma widget archive";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
