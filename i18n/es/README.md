# keyboard-helios-16-neo

🌐 [Português](../../README.md) · [English](../en/README.md) · **Español**

RGB del teclado (4 zonas) del **Acer Predator Helios Neo 16 (PHN16-72)** funcionando en Linux.

> [!WARNING]
> **Lee esto antes de usarlo.**
>
> Este repositorio es una copia de la rama original de [Linuwu-Sense](https://github.com/0x7375646F/Linuwu-Sense) con **un único cambio** para que funcione en **mi** modelo: Acer Predator Helios Neo 16 (PHN16-72).
>
> - **No hay ninguna garantía** de que funcione en el tuyo.
> - **No me hago responsable** de ningún daño que pueda sufrir tu portátil.
>
> Nada de esto debería causarle problemas a tu portátil, pero el proyecto reemplaza el driver `acer_wmi` del kernel por un módulo no oficial. Los kernels en los que lo probé están en [Kernels probados](#kernels-probados), y la lista irá creciendo a medida que actualice. Úsalo bajo tu propio riesgo.

## Origen

| | |
|---|---|
| Upstream | https://github.com/0x7375646F/Linuwu-Sense |
| Commit base | `4483b6c38b9bb963ac9ada9ca476578e0c63cc08` (2026-10-19, "Merge pull request #147 from nghiant03/feat/anv15-52") |
| Licencia | GPL-3.0 ([`LICENSE`](../../LICENSE)), heredada del upstream |
| README original | [`README.upstream.md`](../../README.upstream.md) |
| Linaje | fork del `acer-wmi` del kernel, inspirado en [acer-predator-turbo-and-rgb-keyboard-linux-module](https://github.com/JafarAkhondali/acer-predator-turbo-and-rgb-keyboard-linux-module) |

Archivos copiados: todo lo que git rastrea en el commit de arriba, sin `.git` y sin artefactos de compilación. El README del upstream se renombró a `README.upstream.md`, y el enlace en `docs/PHN14-51.md` se ajustó al nuevo nombre.

Archivos propios de este fork: `README.md`, `i18n/`, `helios-kb.sh`, `TESTED_KERNELS`, `patches/` y la línea del parche en `src/linuwu_sense.c`.

## Probado en

| | |
|---|---|
| Portátil | Acer Predator Helios Neo 16, **PHN16-72** (DMI product `Predator PHN16-72`, board `EQE_RTX`) |
| BIOS | V1.14 (2024-09-19) |
| SO | Ubuntu 24.04 |
| Compilador | gcc 13.3.0 |
| Secure Boot | activado, con la validación desactivada en shim; DKMS firma el módulo con la MOK de `/var/lib/shim-signed/mok/` |

### Kernels probados

La fuente de verdad es el archivo [`TESTED_KERNELS`](../../TESTED_KERNELS), que `helios-kb.sh` lee y muestra en el aviso inicial.

| Kernel | Distro | Fecha | Resultado |
|---|---|---|---|
| `7.0.0-42-generic` | Ubuntu 24.04 | 2026-11-09 | OK (`per_zone_mode` + `four_zone_mode`) |

Oficialmente, el upstream solo prueba en kernels 6.12 a 6.14.

## El problema

- El `acer_wmi` del kernel no expone la luz del teclado de este modelo: no hay LED de teclado en `/sys/class/leds`.
- El teclado es RGB de 4 zonas, controlado por el EC vía WMI (GUID `7A4DDFE7-5B5D-40B4-8595-4408E0CC7F56`). No aparece ningún dispositivo USB/HID de RGB, así que OpenRGB no sirve.
- Sin el parche, Linuwu-Sense carga, pero:
  - `four_zone_mode` con un efecto animado (p. ej., wave) **enciende**.
  - `per_zone_mode` (color fijo por zona) **no hace nada**: el EC guarda el color, pero no lo muestra.
  - `four_zone_mode` en el modo 0 (static) **apaga** el teclado.

## El parche

[`patches/0001-phn16-72-kb-zone-arm.patch`](../../patches/0001-phn16-72-kb-zone-arm.patch), ya aplicado en `src/linuwu_sense.c`:

```diff
  static struct quirk_entry quirk_acer_predator_phn16_72 = {
     .predator_v4 = 1,
     .four_zone_kb = 1,
+    .kb_zone_arm = 1,      /* teste local PHN16-72 */
  };
```

Con `kb_zone_arm`, el driver ejecuta `gaming_kb_arm_zones()` en el probe: consulta `GET_GAMING_SYS_INFO` y llama a `SET_GAMING_LED` con "on + todas las zonas". Sin eso, las zonas de LED quedan desarmadas y el color fijo nunca aparece. El PH315-53 se comporta igual y ya usaba este quirk en el upstream.

## Atajo: `helios-kb.sh`

El script cubre todos los pasos de abajo, con comprobaciones: modelo, parche presente, vermagic del `.ko`, sysfs y dmesg. `./helios-kb.sh --help` lo lista todo.

Cada ejecución empieza con el aviso de riesgo (en inglés, con colores y parpadeando) y la lista de kernels probados, indicando si el kernel en ejecución está en ella. Los comandos que cambian módulos del kernel (`--smoke-test` y `--install`) solo continúan después de que escribas **Y** en "I understand the risks". Para automatizar, usa `--yes` o `HELIOS_KB_ACCEPT_RISK=1`.

La salida del script (salvo el aviso) está en portugués.

| Comando | Qué hace |
|---|---|
| `--make [--kver X]` | Compila para el kernel actual o para `X`. Con `X` puedes probar un kernel recién instalado **antes** de reiniciar |
| `--smoke-test` | Carga la compilación local sin instalarla, enciende las 4 zonas (rojo/verde/azul/blanco) y pregunta si se encendieron |
| `--install` | Compila primero (falla pronto), ejecuta `sudo make install` y comprueba DKMS, módulo, sysfs, servicio y grupo |
| `--uninstall` | `sudo make uninstall` |
| `--restore` | Vuelve a cargar `acer_wmi` hasta el próximo arranque |
| `--status` | Diagnóstico general, incluido si DKMS tiene una compilación para el kernel en ejecución |
| `--check-patch` | Comprueba que el quirk del PHN16-72 esté en el código fuente |
| `--color HEX [HEX HEX HEX] [BRILLO]` | Color fijo (1 color = todas las zonas) |
| `--effect MODO [VEL] [BRILLO] [DIR] [HEX]` | Efecto animado (`wave`, `breathing`, `neon`, `shifting`, `zoom` o 0-7) |
| `--off` | Brillo 0, manteniendo los colores |
| `--clean` | Borra los artefactos de compilación |

Flujo típico: `--make` → `--smoke-test` → `--install` → reinicio → `--status`.

¿Llegó un kernel nuevo por apt? Ejecuta `./helios-kb.sh --make --kver <versión-nueva>` antes de reiniciar. Si falla, corrígelo aquí primero (ver [Cuando un kernel nuevo lo rompa](#cuando-un-kernel-nuevo-lo-rompa)).

## Instalación manual

Requisitos (Ubuntu):

```bash
sudo apt install linux-headers-$(uname -r) dkms build-essential git
```

### 1. Prueba temporal (un reinicio la deshace)

```bash
make -C /lib/modules/$(uname -r)/build M=$PWD modules
sudo modprobe -a wmi sparse-keymap hid video
sudo rmmod acer_wmi && sudo insmod src/linuwu_sense.ko
sudo dmesg | grep linuwu | tail
```

Avisos que pueden aparecer al compilar, todos inofensivos:
- `the compiler differs`: es el mismo gcc, solo cambia el nombre del binario.
- `pahole version differs` / `Skipping BTF generation`: sin BTF el módulo solo pierde información de depuración usada por eBPF.

Para volver al original sin reiniciar: `sudo rmmod linuwu_sense && sudo modprobe acer_wmi`.

### 2. Instalación permanente (DKMS)

```bash
sudo make install
```

Qué hace:
- Pone `acer_wmi` en la blacklist (`/etc/modprobe.d/blacklist-acer_wmi.conf`).
- Copia el código fuente a `/usr/src/linuwu_sense-1.0` y lo compila, firma e instala vía DKMS en `/lib/modules/<kernel>/updates/dkms/`. Con cada kernel nuevo, DKMS lo recompila solo.
- Habilita `linuwu_sense.service`, que restaura el estado al arrancar.
- Instala el comando `linuwu-sense` y la app gráfica "Penguin Sense".
- Añade tu usuario al grupo `linuwu_sense`. Tras cerrar sesión y volver a entrar, puedes escribir en sysfs sin `sudo`.

Comprobar: `dkms status`.

### Desinstalar

```bash
sudo make uninstall
```

Quita el módulo de DKMS, elimina la blacklist y vuelve a cargar el `acer_wmi` original.

## Uso del teclado

**Atención:** en el PHN16-72 la ruta real es `acer-wmi/four_zoned_kb/`, no `predator_sense/four_zoned_kb/` como dice el README del upstream.

```bash
B=/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb
```

Color fijo por zona: `RRGGBB` × 4 zonas, más el brillo (0-100):

```bash
echo "ff0000,00ff00,0000ff,ffffff,100" | sudo tee $B/per_zone_mode
```

Efecto: `modo(0-7),velocidad(0-9),brillo(0-100),dirección(1-2),R,G,B`:

```bash
echo "3,4,100,1,0,0,255" | sudo tee $B/four_zone_mode   # wave
```

Modos: 0 static, 1 breathing, 2 neon, 3 wave, 4 shifting, 5 zoom, 6 y 7 (ver el código fuente). Para leer el estado actual: `cat $B/per_zone_mode $B/four_zone_mode`. Tras la instalación, los archivos quedan `0660 root:linuwu_sense`, así que la lectura también necesita `sudo` hasta que entres en el grupo.

También hay atributos en `acer-wmi/predator_sense/`: `backlight_timeout`, `battery_limiter`, `battery_calibration`, `fan_speed`, `usb_charging`, `lcd_override` y `boot_animation_sound`.

## Cuando un kernel nuevo lo rompa

1. Ver el error de DKMS: `dkms status` y `/var/lib/dkms/linuwu_sense/1.0/build/make.log`.
2. Reproducir la compilación aquí: `./helios-kb.sh --make --kver <versión>`.
3. Comparar con el `drivers/platform/x86/acer-wmi.c` del kernel nuevo. Linuwu es un fork de ese archivo, así que los cambios de API suelen aparecer allí primero (p. ej., `platform_profile`, `wmi_*`, `hwmon`).
4. Comprobar si el upstream ya lo corrigió y, si es así, traer el commit manteniendo el parche del PHN16-72.
5. Reinstalar tras corregir: `./helios-kb.sh --uninstall && ./helios-kb.sh --install`.
6. ¿Funcionó? Añade el kernel a [`TESTED_KERNELS`](../../TESTED_KERNELS) y a la tabla de los tres README.

Salida de emergencia mientras no se corrige: `./helios-kb.sh --uninstall`. Vuelve el `acer_wmi` del kernel y todo lo demás funciona, solo que sin luz en el teclado.

## Pendientes

- Abrir un PR de una línea en el upstream añadiendo `kb_zone_arm = 1` al PHN16-72.
- Confirmar que el color vuelve solo después de un reinicio.

## Licencia

[GPL-3.0](../../LICENSE), la misma del [repositorio original](https://github.com/0x7375646F/Linuwu-Sense). El archivo `LICENSE` es una copia idéntica del upstream. `src/linuwu_sense.c` mantiene la cabecera `SPDX-License-Identifier: GPL-2.0-or-later` heredada del `acer-wmi` del kernel, compatible con la GPL-3.0. Los archivos añadidos por este fork (`helios-kb.sh`, `TESTED_KERNELS`, los README y el parche) siguen la misma GPL-3.0.
