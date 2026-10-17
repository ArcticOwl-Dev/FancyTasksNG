<h1 align="center">Fancy Tasks NG</h1>
<p align="center">
  <img src="package/icon.svg" alt="Fancy Tasks NG"/>
</p>
<p align="center">
  <strong>A feature-rich and highly customizable alternative task manager for KDE Plasma 6.</strong>
</p>
<p align="center">
  <a href="https://github.com/daydve/FancyTasksNG/releases/latest">
    <img src="https://img.shields.io/github/v/release/daydve/FancyTasksNG?style=flat-square&label=Latest%20Release&color=6c63ff" alt="Latest Release"/>
  </a>
  <img src="https://img.shields.io/badge/Plasma-6.5%2B-blue?style=flat-square&logo=kde&logoColor=white" alt="Plasma 6.5+"/>
  <img src="https://img.shields.io/badge/Qt-6-green?style=flat-square&logo=qt&logoColor=white" alt="Qt6"/>
  <img src="https://img.shields.io/badge/License-GPL--3.0-orange?style=flat-square" alt="License"/>
</p>

---

![Fancy Tasks NG Screenshot](media/screenshots.png)

---

## What is this?

**Fancy Tasks NG** is an alternative task manager for KDE Plasma 6. It builds upon the native task manager concepts by offering deeper customization and additional visual features like animated activity indicators, smart notification badges on app icons, volume scroll controls, dynamic hover zoom, centered alignment, and rich tooltips.

## Why this fork exists (A personal story)

I used the original [FancyTasks](https://github.com/alexankitty/FancyTasks) by [alexankitty](https://github.com/alexankitty) for many years. When Plasma 6 came out, I thought the project was dead. Later, I found a fork ([FancyTasksPlus](https://github.com/SushiTrashXD/FancyTasksPlus) by [SushiTrashXD](https://github.com/SushiTrashXD)) that attempted to port it to Plasma 6. 

Unfortunately, as Plasma continued to evolve (especially after 6.4), the code started breaking and the widget stopped working entirely. I temporarily went back to the standard Plasma task manager, but I really missed the features I was used to. 

So, I decided to fork the project for myself just to restore basic compatibility with modern Plasma. After getting it to work, I started making a few small tweaks here and there. What started as a simple compatibility fix quickly grew into a major overhaul. I ended up completely rewriting large chunks of the codebase, removing legacy code, and adding a bunch of new features I had always wanted. Thus, **Fancy Tasks NG** (Next Generation) was born.

## Overview of Capabilities

Fancy Tasks NG is a standalone task manager widget that includes the following features:
- **Alignment:** Built-in option to align tasks to the center of the panel.
- **Background Data Integration:** A custom D-Bus bridge enables the display of unread message badges and task progress bars directly on pinned icons, even if the application has no active windows.
- **Interaction Shortcuts:** Support for adjusting the volume of individual applications via mouse wheel scroll over their icons.
- **Configuration Preview:** A Live Preview component in the settings window displays changes in real time before they are applied.
- **Visual Effects:** Configurable options for icon hover zoom animations, custom indicator styles, and particle effects when closing windows.

For a complete list of features and version history, refer to the [CHANGELOG](CHANGELOG.md).

## Application rules and window titles (development)

The **Filter** settings page contains allow/block rules, an open-window
inspector and per-app title overrides. Global window title settings are in
**Appearance**, below the Classic panel / Show icons only selection. Rules match App ID or App Name; blocks take
priority. The inspector can prepare rules and title overrides without matching
window titles as application identities. Changes take effect after Apply.

In the icon-only layout, Automatic titles show one window as an icon and two or
more eligible windows as separate labeled buttons. Always labeled and per-app
Inherit/Icon only/Labeled overrides are available. Width animation defaults to
200ms; Maximum button width remains in Appearance. Classic mode is retained.

For hover clipping on a non-floating bottom panel, Nix builds include an optional
native renderer. Enable **Advanced → Experimental floating overlay** and Apply.
It draws the same task row in a larger transparent surface, keeping the panel's
height and background. It is off by default and currently supports bottom
horizontal Wayland panels. Other layouts or unavailable native support retain
normal rendering.

To return to the previous task presentation, set filtering Off, set title mode
Off and remove title overrides or set them to Inherit. These options do not
change the saved launcher list.

## Requirements

- **KDE Plasma 6.5** (or newer)

## How to install

### From source (Highly Recommended)
This is the best way to ensure you have the absolute latest version:

```bash
# 1. Grab the code
git clone https://github.com/daydve/FancyTasksNG.git
cd FancyTasksNG

# 2. Build and install (this handles everything for you)
make install
```
Once it's done, right-click your panel, select **Add Widgets**, and look for **"Fancy Tasks NG"**.

### From a pre-built package
If you prefer not to use `make`, you can download the latest `FancyTasksNG.plasmoid` file from the [Releases page](https://github.com/daydve/FancyTasksNG/releases) and install it from the terminal:

```bash
kpackagetool6 -t Plasma/Applet --install FancyTasksNG.plasmoid
```

### Testing an in-development build

To build an installable package with Nix from this repository:

```bash
nix build .#plasmoid
# Output: result/FancyTasksNG.plasmoid
```

Nix packages include a Python runtime with `dbus-python` and `pygobject3` for
configuration import/export, desktop actions and badge integration. The helpers
use its absolute store path, so Plasma does not need `python3` on its PATH.
Keep the package output in your Nix profile or a GC root (such as the `result`
symlink) while using the widget: the installed archive refers to its runtime
and native libraries in the Nix store. The `install-dev` command below creates
this root automatically in `$XDG_STATE_HOME/fancytasksng` (defaulting to
`~/.local/state/fancytasksng`). After uninstalling the dev widget, remove its
`io.github.daydve.fancytasksng.m1test` symlink there to release that root.
These Nix-built archives are intended for
the machine where they were built; they are not standalone release archives.

For panel testing alongside an existing Fancy Tasks NG installation, build the
separate **Fancy Tasks NG (Dev)** widget instead:

```bash
nix build .#plasmoid-test
# Output: result/FancyTasksNG-M1-Test.plasmoid
```

To build and install it in one command:

```bash
nix run .#install-dev
```

Then use the panel's **Add Widgets** menu to add **Fancy Tasks NG (Dev)**.
Run the same command after making changes: it upgrades an existing test
installation under the same widget ID, keeping its panel instance and settings.
It uses your installed `kpackagetool6` and does not update the regular Fancy Tasks
NG package. After a successful install or upgrade, it runs
`systemctl --user restart plasma-plasmashell.service` so the widget loads the
updated QML. Panels briefly reload; application windows remain open. This
requires a Plasma session managed by that systemd user service. A failed
installation does not restart Plasma.

The dev widget previously appeared as **Fancy Tasks NG (M1 Test)**. Its ID and
archive filename retain `m1test`/`M1-Test` so upgrades keep working. The name does
not indicate which milestones are included. Plasma's existing **About** dialog
shows the build commit after the version, for example `2.2.0-cd42d65`. The isolated
source preview also includes its commit; `-dirty` means uncommitted changes were
included. An installed package version does not guarantee an existing widget
instance has reloaded its QML.

The test widget has its own ID and per-widget configuration; the original package
keeps the normal Fancy Tasks NG ID. Both builds use the locked dependencies,
compile the committed translations, and create the archive in the Nix store
without modifying the checkout. Building does not install anything or restart
Plasma. To remove the test installation, first remove its widget from the panel,
then run `kpackagetool6 -t Plasma/Applet --remove io.github.daydve.fancytasksng.m1test`.

For local development on NixOS, open a terminal in this repository and run:

```bash
nix develop
fancytasks-preview
```

The locked development shell supplies the build and test tools. The preview
uses your installed `plasmawindowed` so it matches your Plasma desktop. It copies
the current source, including uncommitted edits, into a temporary directory with
isolated settings. Closing the preview discards those settings and removes the
copy. Nothing is installed and Plasma is not restarted.

The shell includes Python with `dbus-python` and `pygobject3` for the existing
badge and desktop-action helpers. An installed widget needs those modules in
the Python environment used by Plasma too; installing a `.plasmoid` does not
install system packages or change the Plasma session's environment.

You can also launch it directly with `nix run .#preview`. To run the automated
rule, defaults and shell syntax checks, use `nix flake check`. Inside the shell,
`make build` creates `release/FancyTasksNG.plasmoid` and may regenerate translation
files in the checkout; review those changes before committing them.

Want to try a fix or feature before it's released? Every commit to `develop` that touches the widget gets built automatically and uploaded as a workflow artifact — no need to build it yourself. Grab it from the **[Nightly Build workflow runs](https://github.com/daydve/FancyTasksNG/actions/workflows/nightly.yml)**: open the latest successful run and download the `.plasmoid` from its Artifacts section (requires being signed in to GitHub), then install it the same way as above.

*(These are unreleased, in-progress builds — expect rough edges. The version shown in the widget's settings tells you exactly which commit it was built from.)*

### From the KDE Store
You can also grab it from the [KDE Store](https://store.kde.org/p/2350434) straight through the Plasma "Get New Widgets" dialog.
*(Note: The KDE Store version might occasionally be a bit behind the GitHub releases.)*

## Keeping it updated

If you installed from source, updating is a breeze. Just open a terminal in your cloned `FancyTasksNG` folder and run:

```bash
git pull
make update
```
This will fetch the latest code, recompile what's needed, install the update, and seamlessly restart Plasma for you. 

## Uninstallation

If you ever need to remove it, make sure you first delete any Fancy Tasks NG widgets from your panels. Then run:

```bash
make uninstall
```

## Contributing

Found a bug? Have a great idea for a feature? Want to help translate the widget into your language? All contributions are welcome! 

Head over to the [GitHub Issues tracker](https://github.com/daydve/FancyTasksNG/issues) to report bugs or request features. If you want to help with translations, you'll find the `.po` files in the `tools/translate/` directory.

## Acknowledgements

This project wouldn't exist without the amazing work of the original authors and the KDE community. A massive thank you to:

| Who | What they did |
|---|---|
| [SushiTrashXD](https://github.com/SushiTrashXD) | Created FancyTasksPlus (the initial Plasma 6 port that served as the base for this fork). |
| [Alexandra Stone](https://github.com/alexankitty) | Created the original FancyTasks for Plasma 5, pioneering the animated indicators and badges. |
| [Luis Bocanegra](https://github.com/luisbocanegra) | Implemented the original hover-zoom logic. |
| The Community | Everyone who has submitted bug reports, PRs, and ideas. |

---

<p align="center">
  <sub>Licensed under GPL-3.0-or-later &nbsp;·&nbsp; Maintained by <a href="https://github.com/daydve">Vitaliy Elin</a></sub>
</p>
