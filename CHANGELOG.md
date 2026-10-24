# Changelog

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
