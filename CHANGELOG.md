# Changelog

## 1.4.0 (2026-11-02)

- Colour fix with vkBasalt (optional): `--vkbasalt on|off`, `--saturation` and `--contrast` (0.5-2.0, default 1.05), `--sharpness` (AMD CAS, 0-1, default 0.3, 0 = off). The script writes a 17³ colour table (`colour.cube`) and `vkBasalt.conf` next to the settings on every start. Nothing neutral is loaded: at 1.0 / 1.0 / 0 vkBasalt stays off
- `--vkbasalt-key` (default `Scroll_Lock`): key that switches the effect on/off in game, to compare. Not Home, L2 uses it for the camera
- `--check` shows the vkBasalt layer in 64- and 32-bit (`found` / `missing`) and which one `L2.exe` needs, with the package names for Arch (AUR), Debian/Ubuntu and Fedora. With `--vkbasalt on` and the needed one missing, every start warns
- `L2_VKBASALT=on|off` for one start; `--settings` shows the colour values

## 1.3.0 (2026-11-02)

- Finds the client exe also in `system-*` folders (e.g. `system-eu` of EU clients), not only `system/`.
- Starts the exe from its own folder, so clients with a renamed system folder load their files.

## 1.2.0 — 2026-10-24

- Start it again (terminal or menu entry) while it runs → the next window opens (box 2, 3 ... up to 9), like on Windows. `--multi off` brings back "already running"
- `--kill` without `--box` stops every window of the client; `--box N --kill` only that one

## 1.1.1 — 2026-10-24

- `--box N --desktop` uses `<name>N.png` as icon if it exists (own icon per box), else `<name>.png`

## 1.1.0 — 2026-10-24

- `--box N` (2-9): more windows of the same client (multibox). Each box has its own Wine prefix (`prefix-boxN`), log and window class (`steam_app_<name>N`); settings are shared
- The "already running" check now looks at the prefix, so boxes and other clients don't block each other

## 1.0.1 — 2026-10-24

- Refuses a second start of the same client: Proton waited behind the running one, which looked like a hang
- `--kill`: stops this client and any stuck start (wineserver -k on its prefix)

## 1.0.0 — 2026-10-24

First public version.

- GE-Proton9-27 and umu-launcher 1.4.4, pinned with sha512 / sha256 checks
- Own Wine prefix per client, named after the script file
- Saved settings per client: `--fps`, `--hud`, `--mangohud`, `--title`
- `--check`: Python, download tools, user namespaces, Vulkan driver in the bitness of `L2.exe` (PE header + ICD ELF class), disk space
- `--desktop`, `--winecfg`, `--reset-prefix`, `--version`
- Finds `system/L2.exe` in any case (`l2.exe`)
- Reuses GE-Proton9-27 from Steam's `compatibilitytools.d` if present
