{ stdenv, cmake, qt6, src }:
stdenv.mkDerivation {
  pname = "fancytasksng-native";
  version = "1";
  inherit src;
  sourceRoot = "source/native";
  nativeBuildInputs = [ cmake ];
  buildInputs = [ qt6.qtbase qt6.qtdeclarative ];
  dontWrapQtApps = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export XDG_CACHE_HOME="$TMPDIR/cache"
    mkdir -p "$XDG_CACHE_HOME"
    QT_QPA_PLATFORM=offscreen ctest --output-on-failure
    runHook postCheck
  '';
}
