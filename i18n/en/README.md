# keyboard-helios-16-neo

🌐 [Português](../../README.md) · **English** · [Español](../es/README.md)

4-zone keyboard RGB on the **Acer Predator Helios Neo 16 (PHN16-72)**, working on Linux.

> [!WARNING]
> **Read before using.**
>
> This repository is a copy of the original [Linuwu-Sense](https://github.com/0x7375646F/Linuwu-Sense) branch with **a single change** to make it work on **my** model: Acer Predator Helios Neo 16 (PHN16-72).
>
> - **There is no warranty** that it will work on yours.
> - **I am not responsible** for any damage that may happen to your notebook.
>
> Nothing here should harm your laptop, but it replaces the kernel's `acer_wmi` driver with an unofficial module. The kernels I have tested are listed under [Tested kernels](#tested-kernels), and the list will grow as I upgrade. Use at your own risk.

## Origin

| | |
|---|---|
| Upstream | https://github.com/0x7375646F/Linuwu-Sense |
| Base commit | `4483b6c38b9bb963ac9ada9ca476578e0c63cc08` (2026-10-19, "Merge pull request #147 from nghiant03/feat/anv15-52") |
| License | GPL-3.0 ([`LICENSE`](../../LICENSE)), inherited from upstream |
| Original README | [`README.upstream.md`](../../README.upstream.md) |
| Lineage | fork of the kernel's `acer-wmi`, inspired by [acer-predator-turbo-and-rgb-keyboard-linux-module](https://github.com/JafarAkhondali/acer-predator-turbo-and-rgb-keyboard-linux-module) |

Copied files: everything git tracks at the commit above, without `.git` and without build artifacts. The upstream README was renamed to `README.upstream.md`, and the link in `docs/PHN14-51.md` was updated to the new name.

Files added by this fork: `README.md`, `i18n/`, `helios-kb.sh`, `TESTED_KERNELS`, `patches/`, plus the patch line in `src/linuwu_sense.c`.

## Tested on

| | |
|---|---|
| Laptop | Acer Predator Helios Neo 16, **PHN16-72** (DMI product `Predator PHN16-72`, board `EQE_RTX`) |
| BIOS | V1.14 (2024-09-19) |
| OS | Ubuntu 24.04 |
| Compiler | gcc 13.3.0 |
| Secure Boot | enabled, with validation disabled in shim; DKMS signs the module with the MOK in `/var/lib/shim-signed/mok/` |

### Tested kernels

The source of truth is [`TESTED_KERNELS`](../../TESTED_KERNELS), which `helios-kb.sh` reads and shows in its startup warning.

| Kernel | Distro | Date | Result |
|---|---|---|---|
| `7.0.0-42-generic` | Ubuntu 24.04 | 2026-11-09 | OK (`per_zone_mode` + `four_zone_mode`) |

Upstream officially tests only kernels 6.12 to 6.14.

## The problem

- The kernel's `acer_wmi` does not expose this model's keyboard light: there is no keyboard LED in `/sys/class/leds`.
- The keyboard is 4-zone RGB, driven by the EC through WMI (GUID `7A4DDFE7-5B5D-40B4-8595-4408E0CC7F56`). There is no USB/HID RGB device, so OpenRGB can't help.
- Without the patch, Linuwu-Sense loads, but:
  - `four_zone_mode` with an animated effect (e.g. wave) **lights up**.
  - `per_zone_mode` (static color per zone) **does nothing**: the EC stores the color but never shows it.
  - `four_zone_mode` in mode 0 (static) **turns the keyboard off**.

## The patch

[`patches/0001-phn16-72-kb-zone-arm.patch`](../../patches/0001-phn16-72-kb-zone-arm.patch), already applied to `src/linuwu_sense.c`:

```diff
  static struct quirk_entry quirk_acer_predator_phn16_72 = {
     .predator_v4 = 1,
     .four_zone_kb = 1,
+    .kb_zone_arm = 1,      /* teste local PHN16-72 */
  };
```

With `kb_zone_arm`, the driver runs `gaming_kb_arm_zones()` at probe: it queries `GET_GAMING_SYS_INFO` and calls `SET_GAMING_LED` with "on + all zones". Without it, the LED zones stay disarmed and static colors never show up. The PH315-53 behaves the same way and already used this quirk upstream.

## Shortcut: `helios-kb.sh`

The script covers every step below, with checks: model, patch present, `.ko` vermagic, sysfs, and dmesg. `./helios-kb.sh --help` lists everything.

Every run starts with the risk warning (colored and blinking) and the list of tested kernels, flagging whether the running kernel is on it. Commands that swap kernel modules (`--smoke-test` and `--install`) only proceed after you type **Y** at "I understand the risks". For automation, use `--yes` or `HELIOS_KB_ACCEPT_RISK=1`.

The script's output (apart from the warning) is in Portuguese.

| Command | What it does |
|---|---|
| `--make [--kver X]` | Builds for the running kernel or for `X`. With `X`, you can test a freshly installed kernel **before** rebooting |
| `--smoke-test` | Loads the local build without installing, lights the 4 zones (red/green/blue/white), and asks whether they lit up |
| `--install` | Builds first (fails early), runs `sudo make install`, and checks DKMS, module, sysfs, service, and group |
| `--uninstall` | `sudo make uninstall` |
| `--restore` | Brings back `acer_wmi` until the next boot |
| `--status` | Overall diagnosis, including whether DKMS has a build for the running kernel |
| `--check-patch` | Checks that the PHN16-72 quirk is in the source |
| `--color HEX [HEX HEX HEX] [BRIGHTNESS]` | Static color (1 color = all zones) |
| `--effect MODE [SPEED] [BRIGHTNESS] [DIR] [HEX]` | Animated effect (`wave`, `breathing`, `neon`, `shifting`, `zoom`, or 0-7) |
| `--off` | Brightness 0, keeping the colors |
| `--clean` | Removes build artifacts |

Typical flow: `--make` → `--smoke-test` → `--install` → reboot → `--status`.

New kernel arrived via apt: run `./helios-kb.sh --make --kver <new-version>` before rebooting. If it fails, fix it here first (see [When a new kernel breaks it](#when-a-new-kernel-breaks-it)).

## Manual installation

Prerequisites (Ubuntu):

```bash
sudo apt install linux-headers-$(uname -r) dkms build-essential git
```

### 1. Temporary test (a reboot undoes it)

```bash
make -C /lib/modules/$(uname -r)/build M=$PWD modules
sudo modprobe -a wmi sparse-keymap hid video
sudo rmmod acer_wmi && sudo insmod src/linuwu_sense.ko
sudo dmesg | grep linuwu | tail
```

Build warnings you may see, all harmless:
- `the compiler differs`: same gcc, only the binary name differs.
- `pahole version differs` / `Skipping BTF generation`: without BTF the module only loses debug info used by eBPF.

To go back to the original without rebooting: `sudo rmmod linuwu_sense && sudo modprobe acer_wmi`.

### 2. Permanent installation (DKMS)

```bash
sudo make install
```

What it does:
- Blacklists `acer_wmi` (`/etc/modprobe.d/blacklist-acer_wmi.conf`).
- Copies the source to `/usr/src/linuwu_sense-1.0`, then builds, signs, and installs it through DKMS into `/lib/modules/<kernel>/updates/dkms/`. DKMS rebuilds it automatically for every new kernel.
- Enables `linuwu_sense.service`, which restores the state at boot.
- Installs the `linuwu-sense` command and the "Penguin Sense" GUI app.
- Adds your user to the `linuwu_sense` group. After logging out and back in, you can write to sysfs without `sudo`.

Check: `dkms status`.

### Uninstall

```bash
sudo make uninstall
```

Removes the module from DKMS, removes the blacklist, and reloads the original `acer_wmi`.

## Using the keyboard

**Note:** on the PHN16-72 the actual path is `acer-wmi/four_zoned_kb/`, not `predator_sense/four_zoned_kb/` as the upstream README says.

```bash
B=/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb
```

Static color per zone: `RRGGBB` × 4 zones, plus brightness (0-100):

```bash
echo "ff0000,00ff00,0000ff,ffffff,100" | sudo tee $B/per_zone_mode
```

Effect: `mode(0-7),speed(0-9),brightness(0-100),direction(1-2),R,G,B`:

```bash
echo "3,4,100,1,0,0,255" | sudo tee $B/four_zone_mode   # wave
```

Modes: 0 static, 1 breathing, 2 neon, 3 wave, 4 shifting, 5 zoom, 6 and 7 (see the source). Read the current state with `cat $B/per_zone_mode $B/four_zone_mode`. After installation the files are `0660 root:linuwu_sense`, so reading also needs `sudo` until you join the group.

There are also attributes under `acer-wmi/predator_sense/`: `backlight_timeout`, `battery_limiter`, `battery_calibration`, `fan_speed`, `usb_charging`, `lcd_override`, and `boot_animation_sound`.

## When a new kernel breaks it

1. Check the DKMS error: `dkms status` and `/var/lib/dkms/linuwu_sense/1.0/build/make.log`.
2. Reproduce the build here: `./helios-kb.sh --make --kver <version>`.
3. Compare with `drivers/platform/x86/acer-wmi.c` from the new kernel. Linuwu is a fork of that file, so API changes usually show up there first (e.g. `platform_profile`, `wmi_*`, `hwmon`).
4. Check whether upstream already fixed it. If so, bring the commit over and keep the PHN16-72 patch.
5. Reinstall after fixing: `./helios-kb.sh --uninstall && ./helios-kb.sh --install`.
6. Did it work? Add the kernel to [`TESTED_KERNELS`](../../TESTED_KERNELS) and to the table in all three READMEs.

Emergency exit while it isn't fixed: `./helios-kb.sh --uninstall`. The kernel's `acer_wmi` comes back and everything else works, just without keyboard lighting.

## To do

- Open a one-line PR upstream adding `kb_zone_arm = 1` to the PHN16-72.
- Confirm that the color comes back by itself after a reboot.

## License

[GPL-3.0](../../LICENSE), the same as the [original repository](https://github.com/0x7375646F/Linuwu-Sense). The `LICENSE` file is an identical copy of upstream's. `src/linuwu_sense.c` keeps the `SPDX-License-Identifier: GPL-2.0-or-later` header inherited from the kernel's `acer-wmi`, which is compatible with GPL-3.0. Files added by this fork (`helios-kb.sh`, `TESTED_KERNELS`, the READMEs, and the patch) are under the same GPL-3.0.
