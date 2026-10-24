# l2launch

Start a **Lineage II** client on Linux **without Steam**, on any distro, with one script.

- No Wine, Proton, Lutris or Steam to install. The first start downloads everything into your home folder.
- **GE-Proton9-27** and **umu-launcher 1.4.4**, pinned. Every download is checked against a checksum written in the script.
- Proton runs inside Valve's **Steam Linux Runtime** container, so it behaves the same on Arch, Debian/Ubuntu, Fedora, openSUSE and SteamOS.
- **Own Wine prefix per client.** Rename the script and you have a second, separate client.
- **Frame limit** (default 60), fps counter, MangoHud, application-menu entry.
- **`--check`** tells you what your PC is missing before anything is downloaded.

Written for the L2Nostos server (Classic 2.7 Antharas, protocol 140), usable for other L2 clients of the same generation.

---

## Quick start

```bash
cd /path/to/your/L2/client                    # the folder where system/ is
curl -LO https://raw.githubusercontent.com/pls-chris/l2launch/main/l2launch.sh
mv l2launch.sh l2myserver.sh                  # name it after the server
chmod +x l2myserver.sh
./l2myserver.sh --check                       # checks your PC, downloads nothing
./l2myserver.sh                               # play
```

The first start takes some minutes (about 650 MB download), then every start is fast.

```bash
./l2myserver.sh --title "My Server"           # name in messages and in the menu
./l2myserver.sh --desktop                     # add it to the application menu
```

For a menu icon, put a PNG with the same name next to the script (`l2myserver.png`).

---

## What your PC needs

| Need | Why | How to get it |
|---|---|---|
| 64-bit PC (x86_64) | Proton only runs there | — |
| Python 3.10 or newer | umu-run is a Python program | almost every distro has it already |
| curl or wget, tar | first download | almost every distro has them already |
| **Vulkan driver in the bitness of `L2.exe`** | the game draws with Vulkan (DXVK) | `--check` reads `L2.exe` and tells you. Most L2 clients are **32-bit** |
| User namespaces allowed | the runtime container needs them | default on most distros, see Troubleshooting for Ubuntu |
| ~3 GB free disk | Proton + runtime + Wine prefix | in your home folder |
| Internet on the first start | downloads | — |

**32-bit Vulkan driver.** Every distro has the normal 64-bit one. The 32-bit one is what most people miss:

| Distro | AMD | Intel | NVIDIA |
|---|---|---|---|
| Arch, CachyOS, Manjaro, EndeavourOS | `lib32-vulkan-radeon` | `lib32-vulkan-intel` | `lib32-nvidia-utils` |
| Debian, Ubuntu, Mint, Pop!_OS | `sudo dpkg --add-architecture i386 && sudo apt update && sudo apt install mesa-vulkan-drivers:i386` | same | the `:i386` package of your NVIDIA driver |
| Fedora | `mesa-vulkan-drivers.i686` | same | `xorg-x11-drv-nvidia-libs.i686` (RPM Fusion) |

(On Arch the `lib32-` packages need the `[multilib]` repo.)

Works on: Arch/CachyOS, Debian/Ubuntu, Fedora, openSUSE, SteamOS and other immutable distros. Nothing is installed system-wide, and no root is needed. It does **not** work on ARM PCs or on musl distros (Alpine).

---

## Several clients

The **file name** of the script decides everything that belongs to one client:

| | `l2nostos.sh` | `l2dion.sh` |
|---|---|---|
| Wine prefix | `~/.local/share/l2nostos/prefix` | `~/.local/share/l2dion/prefix` |
| Settings | `~/.config/l2nostos/launcher.conf` | `~/.config/l2dion/launcher.conf` |
| Menu entry (`--desktop`) | its `--title`, icon `l2nostos.png` | its `--title`, icon `l2dion.png` |
| Window class | `steam_app_l2nostos` | `steam_app_l2dion` |
| Proton + umu | shared (`~/.local/share/l2launch/`), downloaded once | shared |

Only letters and digits count in the name (`l2-dion.sh` becomes `l2dion`).

---

## Several windows of one client (multibox)

```bash
./l2myserver.sh                  # window 1
./l2myserver.sh --box 2          # window 2
./l2myserver.sh --box 3          # window 3 (up to --box 9)
./l2myserver.sh --box 2 --kill   # stop only window 2
./l2myserver.sh --box 2 --desktop
```

- Every box has its **own Wine prefix** (`~/.local/share/<name>/prefix-box2`, a few hundred MB, the first start of a box takes a minute). In one shared prefix a second start would only wait behind the first one.
- Settings (fps, HUD, title) are shared by all boxes.
- Window class: `steam_app_<name>2`, `steam_app_<name>3`… — window rules should match `^steam_app_<name>[0-9]*$`.
- Each window needs its **own account** (one account can't be online twice), and the **server** decides how many windows per PC it allows.

---

## Settings

Settings are saved per client and used on every start:

```bash
./l2myserver.sh --fps 144          # frame limit (15-1000), default 60
./l2myserver.sh --fps off          # no frame limit
./l2myserver.sh --hud on           # fps counter in the top-left corner
./l2myserver.sh --mangohud on      # MangoHud overlay instead (if installed)
./l2myserver.sh --title "My Server"
./l2myserver.sh --settings         # show what is set
```

Why 60 by default: L2 does not need more, and without a limit the GPU can run at full power even in the character select screen (heat, fan noise, battery on laptops).

For one start only:

```bash
L2_FPS=off ./l2myserver.sh
L2_HUD=on ./l2myserver.sh
L2_CLIENT=/path/to/client ./l2myserver.sh     # script not inside the client folder
```

Other commands: `--box N` (another window, see above), `--kill` (stop this client, also a stuck start), `--winecfg` (Wine settings of this client's prefix), `--reset-prefix` (fresh prefix, the old one is kept aside), `--version`, `--help`.

---

## How it works

```
l2myserver.sh
 └─ umu-run 1.4.4             launcher by Open Wine Components
     └─ Steam Linux Runtime    Valve's container with fixed libraries
         └─ GE-Proton9-27      Wine + DXVK
             └─ Wine prefix    ~/.local/share/l2myserver/prefix
                 └─ system/L2.exe
```

1. **Check.** It checks the list above and says what is missing.
2. **Download, once.** It downloads GE-Proton9-27 (~450 MB from GitHub) and umu-launcher 1.4.4 (~0.5 MB). Both versions and their checksums are fixed in the script. A damaged or changed download is refused. If Steam already has GE-Proton9-27 in `compatibilitytools.d`, that one is used.
3. **Runtime, once.** On the first start umu-run downloads Valve's Steam Linux Runtime (~200 MB from repo.steampowered.com). Proton runs inside it, so the game sees the same libraries on every distro.
4. **Prefix.** Each client gets its own Wine prefix. It never touches Steam's prefixes or any other Wine setup.
5. **Start.** It starts `system/L2.exe` (any case, `l2.exe` works too). The client draws with Direct3D 9, and DXVK turns that into Vulkan. The frame limit is DXVK's own (`DXVK_FRAME_RATE`).
6. **Log.** Proton's output goes to `~/.local/share/<name>/last-run.log`. When the game exits with an error, the last 25 lines are shown.

**Why GE-Proton 9 and not 10:** the Classic clients we tested crash at login with Proton 10. 9-27 is the last 9.x, so it is pinned on purpose.

**What it does not do:** it starts `L2.exe` directly. A server's own launcher or updater does not run. If a server needs its launcher (to patch files, or to log in with a token), use that server's own Linux instructions. The script does not change, patch or bypass anything in the client.

---

## Files

| Folder | What | Size |
|---|---|---|
| `~/.local/share/l2launch/GE-Proton9-27` | Proton (shared) | 1.3 GB |
| `~/.local/share/l2launch/umu-1.4.4` | umu-run (shared) | 0.5 MB |
| `~/.local/share/<name>/prefix` | Wine prefix of one client | a few hundred MB |
| `~/.local/share/<name>/last-run.log` | log of the last start | small |
| `~/.local/share/umu` | Steam Linux Runtime (shared with other umu games) | under 1 GB |
| `~/.config/<name>/launcher.conf` | settings of one client | tiny |
| `~/.local/share/applications/<name>.desktop` | menu entry (only with `--desktop`) | tiny |

The script never changes the client folder. The game writes its own files there (options, key bindings) like on Windows.

---

## Troubleshooting

**Black screen, or the game closes right away.** Most of the time the 32-bit Vulkan driver is missing. Run `--check`. The log is in `~/.local/share/<name>/last-run.log`.

**"user namespaces are blocked" (Ubuntu 24.04 and newer).** AppArmor blocks them, and the runtime container can not start. Fix:
```bash
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0                                   # until reboot
echo 'kernel.apparmor_restrict_unprivileged_userns=0' | sudo tee /etc/sysctl.d/60-userns.conf  # permanent
```
This turns off one of Ubuntu's security hardening options. Only do it if you need it.

**The camera spins by itself.** A gamepad, or something that looks like one (some headsets, drawing tablets), is read as a joystick. In game: Options → turn off **Support Gamepad**. Server owners can ship `UseJoystick=False` in `L2.ini` / `Option.ini`.

**It stays at "starting…" and nothing opens.** The script prints nothing more while the game runs. The game window may simply be on another workspace or monitor. A second start of the same client is refused ("already running"); `--kill` stops the running one, including a stuck start.

**It stopped starting after it worked before.** `--reset-prefix`, then start again. The old prefix is kept as `prefix.old.<date>`.

**Hyprland: a small empty window stays on screen.** That's the client's splash window: empty title, class `steam_app_<name>` (`steam_app_<name>2`… for boxes). The game window's title is `Lineage II`. Lua config:
```lua
hl.window_rule({
    name      = "l2-splash",
    match     = { class = "^steam_app_l2myserver[0-9]*$", title = "^$" },
    workspace = "special:l2splash silent",
})
```

---

## For server owners

You can ship the script with your client:

1. Rename it after your server (`l2myserver.sh`) and put it in the client root, next to `system/`.
2. Add `l2myserver.png` (menu icon).
3. Tell players to run `./l2myserver.sh --title "My Server"` once, or put a `launcher.conf` note in your guide.
4. Link this README for requirements and troubleshooting.

Players then need nothing else from you for Linux.

---

## Updating the pins (maintainers)

The versions and checksums are at the top of the script (`GE_VER`, `GE_SHA512`, `UMU_VER`, `UMU_SHA256`):

```bash
curl -LO https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-ProtonX-Y/GE-ProtonX-Y.sha512sum
curl -LO https://github.com/Open-Wine-Components/umu-launcher/releases/download/<ver>/umu-launcher-<ver>-zipapp.tar && sha256sum umu-launcher-*-zipapp.tar
```

Test a new Proton with real clients first — the Classic clients we tested crash at login with Proton 10.

---

## Credits

- [GE-Proton](https://github.com/GloriousEggroll/proton-ge-custom) by GloriousEggroll
- [umu-launcher](https://github.com/Open-Wine-Components/umu-launcher) by Open Wine Components
- [Steam Linux Runtime](https://gitlab.steamos.cloud/steamrt/steam-runtime-tools) and [Proton](https://github.com/ValveSoftware/Proton) by Valve, [DXVK](https://github.com/doitsujin/dxvk) by Philip Rebohle

Not affiliated with NCSOFT. Lineage II is a trademark of NCSOFT Corporation. This repository contains no game files.

## License

[MIT](LICENSE) © 2026 Christoforos Pliatsikas
