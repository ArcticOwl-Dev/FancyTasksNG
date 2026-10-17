{ writeShellApplication, plasmoid }:
writeShellApplication {
  name = "fancytasks-install-dev";
  text = ''
    if [[ $# -ne 0 ]]; then
      echo "Usage: nix run .#install-dev" >&2
      exit 2
    fi
    if ! command -v kpackagetool6 > /dev/null 2>&1; then
      echo "kpackagetool6 is required from your installed Plasma desktop." >&2
      exit 1
    fi
    if ! command -v systemctl > /dev/null 2>&1; then
      echo "systemctl is required to restart Plasma Shell after installation." >&2
      exit 1
    fi
    if ! command -v nix-store > /dev/null 2>&1; then
      echo "nix-store is required to retain the installed widget's runtime dependencies." >&2
      exit 1
    fi

    widget_id=io.github.daydve.fancytasksng.m1test
    archive=${plasmoid}/FancyTasksNG-M1-Test.plasmoid
    if kpackagetool6 -t Plasma/Applet --show "$widget_id" > /dev/null 2>&1; then
      echo "Upgrading Fancy Tasks NG (Dev), keeping its widget ID and configuration."
      kpackagetool6 -t Plasma/Applet --upgrade "$archive"
    else
      echo "Installing Fancy Tasks NG (Dev). Add it using the panel's Add Widgets menu."
      kpackagetool6 -t Plasma/Applet --install "$archive"
    fi
    # kpackagetool extracts the archive outside the store. Retain the original
    # package closure so a later garbage collection cannot remove its helpers.
    runtime_root_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/fancytasksng"
    mkdir -p "$runtime_root_dir"
    nix-store --realise ${plasmoid} --add-root "$runtime_root_dir/$widget_id" --indirect > /dev/null
    echo "Restarting Plasma Shell to load the updated widget. Panels will briefly reload."
    if ! systemctl --user restart plasma-plasmashell.service; then
      echo "The widget was installed, but Plasma Shell could not be restarted." >&2
      exit 1
    fi
  '';
}
