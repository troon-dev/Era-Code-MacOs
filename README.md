
# Era-Code-MacOs # 

## macOS

Install Node.js and Python 3 on a Mac, then install the project dependencies:

```bash
npm ci
npm run start:mac
```

The development command starts the local renderer server before opening
Electron, so the launcher interface is available at startup.

Build the app for the Mac you are using with:

```bash
npm run dist:mac
```

This creates a DMG and ZIP in `dist/` for the Mac's current architecture. To
create an architecture-specific ZIP, use `npm run dist:mac:arm64` for Apple
silicon or `npm run dist:mac:x64` for Intel. To build a universal app for
both, run `npm run dist:mac:universal` on macOS. DMG creation, universal
merging, code signing, and notarization require a Mac. Architecture-specific
ZIPs can be cross-built, but these ZIPs are unsigned; public distribution needs
Developer ID signing and Apple notarization. The app registers the
`fluxapp://` authentication link and uses native macOS notifications. The
renderer uses macOS-style window controls and skips the Windows client-DLL
check and download. A native menu provides standard app, edit, and window
actions, including the usual keyboard shortcuts.

The launcher interface and sign-in are available on macOS. The Fortnite
launcher currently starts the Windows client directly on Windows or through
Proton on Linux; starting the game on macOS is not supported yet.

## Linux desktop

Start the Electron interface with:

```bash
npm run start:linux
```

To add a per-user launcher to the application menu and register `fluxapp://`
links, run:

```bash
npm run install:linux-desktop
```

This registration is required for browser-based Discord authentication: after
approving Discord in the browser, its `fluxapp://` callback returns to the
running application. In the AppImage, the OAuth page opens in a launcher-owned
window so the callback is returned directly to the app instead of relying on
the external browser to open the custom protocol. Discord sign-in remains
required.

For an AppImage built in this checkout, register its callback handler with:

```bash
npm run install:appimage-desktop
```

For an AppImage downloaded or moved elsewhere, pass its current path instead:

```bash
bash ./install-era-appimage-integration.sh /path/to/Era-Code.AppImage
```

Run the registration again if you move the AppImage; the desktop entry stores
its absolute path.

The launcher follows the active Wayland/X11 session automatically. If a
specific backend is needed, set `ERA_OZONE_PLATFORM_HINT=wayland` or `x11`
before starting it.

The AppImage packages `app/workers`, `app/binaries`, and `app/build` as
external resources under `resources/workers`, `resources/binaries`, and
`resources/build`, matching the paths used by the Electron main process.
`FortniteLauncher.exe` and `dll_injector.node` are Windows-only helpers and
are not executed on Linux.

On Linux, Era looks for an executable Proton installation in Steam's standard
locations and in additional libraries listed in `libraryfolders.vdf`, including
libraries on other disks. Set `ERA_PROTON_PATH` to the Proton `proton` script
to select a custom install.
The selected build must contain
`FortniteGame/Binaries/Win64/FortniteClient-Win64-Shipping.exe`. Era forwards
its existing launch arguments through Proton, but does not inject the Windows
Era DLL on Linux; the launch callback only means Proton started the process.

Before downloading chunks, Era prepares each incomplete file at its expected
size. Preparation errors such as a read-only destination now stop the download
and are reported instead of being treated as success.
Canceling a download waits for active writes to stop, removes incomplete files
for that build, and preserves files whose chunks are all complete.
Profiler directory scans use asynchronous filesystem reads so large builds do
not block the Electron main process while files are enumerated.

New status alerts are also sent as native desktop notifications on Linux when
the desktop session supports notifications. Alerts already present when the
application starts remain available in the in-app Status Alerts panel and do
not trigger a burst of desktop notifications.
On every Linux startup or relaunch request, Era shows “Era Linux” with the
message “This is a port of Era to Linux.” when desktop notifications are
available.

Automatic launcher updates are disabled to prevent an update from replacing
the Linux launcher. Install a newer AppImage manually when one is available.
Game content updates remain enabled.

The Electron preload API also exposes `validateStoragePath(path, requiredBytes)`
for application-owned storage settings. It creates a missing directory without
deleting data, verifies that it is a writable directory, and reports available
space when the operating system provides it.

The launcher automatically detects the system language and has local interface
translations for Spanish, French, Portuguese, German, and Italian. English and
other unsupported languages use the original English text. Regional variants
such as `pt-BR` are detected automatically; no interface text is sent to an
external translation service.


