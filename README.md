# keyboard-helios-16-neo

🌐 **Português** · [English](i18n/en/README.md) · [Español](i18n/es/README.md)

RGB do teclado (4 zonas) do **Acer Predator Helios Neo 16 (PHN16-72)** funcionando no Linux.

> [!WARNING]
> **Leia antes de usar.**
>
> Este repositório é uma cópia da branch original do [Linuwu-Sense](https://github.com/0x7375646F/Linuwu-Sense) com **uma única alteração** para funcionar no **meu** modelo: Acer Predator Helios Neo 16 (PHN16-72).
>
> - **Não há nenhuma garantia** de que vai funcionar no seu.
> - **Não me responsabilizo** por qualquer dano que possa ocorrer no seu notebook.
>
> Nada aqui deveria causar problema no seu notebook, mas o projeto substitui o driver `acer_wmi` do kernel por um módulo não oficial. Os kernels em que testei estão listados em [Kernels testados](#kernels-testados), e a lista cresce conforme eu for atualizando. Use por sua conta e risco.

## Origem

| | |
|---|---|
| Upstream | https://github.com/0x7375646F/Linuwu-Sense |
| Commit base | `4483b6c38b9bb963ac9ada9ca476578e0c63cc08` (2026-10-19, "Merge pull request #147 from nghiant03/feat/anv15-52") |
| Licença | GPL-3.0 ([`LICENSE`](LICENSE)), herdada do upstream |
| README original | [`README.upstream.md`](README.upstream.md) |
| Linhagem | fork do `acer-wmi` do kernel, inspirado em [acer-predator-turbo-and-rgb-keyboard-linux-module](https://github.com/JafarAkhondali/acer-predator-turbo-and-rgb-keyboard-linux-module) |

Arquivos copiados: tudo o que o git rastreia no commit acima, sem `.git` e sem artefatos de build. O README do upstream foi renomeado para `README.upstream.md`, e o link em `docs/PHN14-51.md` foi ajustado para o novo nome.

Arquivos deste fork: `README.md`, `i18n/`, `helios-kb.sh`, `TESTED_KERNELS`, `patches/` e a linha do patch em `src/linuwu_sense.c`.

## Testado em

| | |
|---|---|
| Notebook | Acer Predator Helios Neo 16, **PHN16-72** (DMI product `Predator PHN16-72`, board `EQE_RTX`) |
| BIOS | V1.14 (2024-09-19) |
| SO | Ubuntu 24.04 |
| Compilador | gcc 13.3.0 |
| Secure Boot | ligado, com validação desativada no shim; o DKMS assina com a MOK em `/var/lib/shim-signed/mok/` |

### Kernels testados

A fonte da verdade é o arquivo [`TESTED_KERNELS`](TESTED_KERNELS), que o `helios-kb.sh` lê e mostra no aviso inicial.

| Kernel | Distro | Data | Resultado |
|---|---|---|---|
| `7.0.0-42-generic` | Ubuntu 24.04 | 2026-11-09 | OK (`per_zone_mode` + `four_zone_mode`) |

Oficialmente, o upstream testa só em kernels 6.12 a 6.14.

## O problema

- O `acer_wmi` do kernel não expõe a luz do teclado desse modelo: não existe LED de teclado em `/sys/class/leds`.
- O teclado é RGB de 4 zonas, controlado pelo EC via WMI (GUID `7A4DDFE7-5B5D-40B4-8595-4408E0CC7F56`). Não aparece nenhum dispositivo USB/HID de RGB, então o OpenRGB não serve.
- Sem patch, o Linuwu-Sense carrega, mas:
  - `four_zone_mode` com efeito animado (ex.: wave) **acende**.
  - `per_zone_mode` (cor fixa por zona) **não faz nada**: o EC grava a cor, mas não mostra.
  - `four_zone_mode` no modo 0 (static) **apaga** o teclado.

## O patch

[`patches/0001-phn16-72-kb-zone-arm.patch`](patches/0001-phn16-72-kb-zone-arm.patch), já aplicado em `src/linuwu_sense.c`:

```diff
  static struct quirk_entry quirk_acer_predator_phn16_72 = {
     .predator_v4 = 1,
     .four_zone_kb = 1,
+    .kb_zone_arm = 1,      /* teste local PHN16-72 */
  };
```

Com `kb_zone_arm`, o driver roda `gaming_kb_arm_zones()` no probe: consulta `GET_GAMING_SYS_INFO` e chama `SET_GAMING_LED` com "on + todas as zonas". Sem isso, as zonas de LED ficam desarmadas e a cor fixa nunca aparece. O PH315-53 tem o mesmo comportamento e já usava esse quirk no upstream.

## Atalho: `helios-kb.sh`

O script cobre todos os passos abaixo, com checagens: modelo, patch presente, vermagic do `.ko`, sysfs e dmesg. `./helios-kb.sh --help` lista tudo.

Toda execução começa com o aviso de risco (em inglês, colorido e piscando) e a lista de kernels testados, indicando se o kernel em execução está nela. Os comandos que trocam módulo do kernel (`--smoke-test` e `--install`) só seguem depois de você digitar **Y** em "I understand the risks". Para automação, use `--yes` ou `HELIOS_KB_ACCEPT_RISK=1`.

| Comando | O que faz |
|---|---|
| `--make [--kver X]` | Compila para o kernel atual ou para `X`. Com `X`, dá para testar um kernel recém-instalado **antes** do reboot |
| `--smoke-test` | Carrega o build local sem instalar, acende as 4 zonas (vermelho/verde/azul/branco) e pergunta se acendeu |
| `--install` | Compila primeiro (falha cedo), roda `sudo make install` e confere DKMS, módulo, sysfs, serviço e grupo |
| `--uninstall` | `sudo make uninstall` |
| `--restore` | Volta o `acer_wmi` até o próximo boot |
| `--status` | Diagnóstico geral, incluindo se o DKMS tem build para o kernel em execução |
| `--check-patch` | Confere se o quirk do PHN16-72 está no fonte |
| `--color HEX [HEX HEX HEX] [BRILHO]` | Cor fixa (1 cor = todas as zonas) |
| `--effect MODO [VEL] [BRILHO] [DIR] [HEX]` | Efeito animado (`wave`, `breathing`, `neon`, `shifting`, `zoom` ou 0-7) |
| `--off` | Brilho 0, mantendo as cores |
| `--clean` | Apaga os artefatos de build |

Fluxo típico: `--make` → `--smoke-test` → `--install` → reboot → `--status`.

Kernel novo chegou pelo apt: `./helios-kb.sh --make --kver <versão-nova>` antes de reiniciar. Se falhar, corrija aqui antes do reboot (ver [Quando um kernel novo quebrar](#quando-um-kernel-novo-quebrar)).

## Instalação manual

Pré-requisitos (Ubuntu):

```bash
sudo apt install linux-headers-$(uname -r) dkms build-essential git
```

### 1. Teste temporário (um reboot desfaz)

```bash
make -C /lib/modules/$(uname -r)/build M=$PWD modules
sudo modprobe -a wmi sparse-keymap hid video
sudo rmmod acer_wmi && sudo insmod src/linuwu_sense.ko
sudo dmesg | grep linuwu | tail
```

Warnings que podem aparecer no build, todos inofensivos:
- `the compiler differs`: é o mesmo gcc, só muda o nome do binário.
- `pahole version differs` / `Skipping BTF generation`: sem BTF o módulo só perde informação de debug para eBPF.

Para voltar ao original sem reboot: `sudo rmmod linuwu_sense && sudo modprobe acer_wmi`.

### 2. Instalação permanente (DKMS)

```bash
sudo make install
```

O que isso faz:
- Coloca o `acer_wmi` na blacklist (`/etc/modprobe.d/blacklist-acer_wmi.conf`).
- Copia o fonte para `/usr/src/linuwu_sense-1.0` e faz build, assinatura e instalação via DKMS em `/lib/modules/<kernel>/updates/dkms/`. A cada kernel novo, o DKMS recompila sozinho.
- Habilita o `linuwu_sense.service`, que restaura o estado no boot.
- Instala o comando `linuwu-sense` e o app gráfico "Penguin Sense".
- Põe o usuário no grupo `linuwu_sense`. Depois de um relogin, dá para escrever no sysfs sem `sudo`.

Conferir: `dkms status`.

### Desinstalar

```bash
sudo make uninstall
```

Remove o módulo do DKMS, tira a blacklist e recarrega o `acer_wmi` original.

## Uso do teclado

**Atenção:** o path real no PHN16-72 é `acer-wmi/four_zoned_kb/`, e não `predator_sense/four_zoned_kb/` como diz o README do upstream.

```bash
B=/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb
```

Cor fixa por zona: `RRGGBB` × 4 zonas, mais o brilho (0-100):

```bash
echo "ff0000,00ff00,0000ff,ffffff,100" | sudo tee $B/per_zone_mode
```

Efeito: `modo(0-7),velocidade(0-9),brilho(0-100),direção(1-2),R,G,B`:

```bash
echo "3,4,100,1,0,0,255" | sudo tee $B/four_zone_mode   # wave
```

Modos: 0 static, 1 breathing, 2 neon, 3 wave, 4 shifting, 5 zoom, 6 e 7 (ver o fonte). Ler o estado atual: `cat $B/per_zone_mode $B/four_zone_mode`. Depois do install, os arquivos ficam `0660 root:linuwu_sense`, então a leitura também precisa de `sudo` até você entrar no grupo.

Também existem atributos em `acer-wmi/predator_sense/`: `backlight_timeout`, `battery_limiter`, `battery_calibration`, `fan_speed`, `usb_charging`, `lcd_override` e `boot_animation_sound`.

## Quando um kernel novo quebrar

1. Ver o erro do DKMS: `dkms status` e `/var/lib/dkms/linuwu_sense/1.0/build/make.log`.
2. Reproduzir o build aqui: `./helios-kb.sh --make --kver <versão>`.
3. Comparar com o `drivers/platform/x86/acer-wmi.c` do kernel novo. O Linuwu é um fork desse arquivo, então mudança de API costuma aparecer lá primeiro (ex.: `platform_profile`, `wmi_*`, `hwmon`).
4. Conferir se o upstream já corrigiu e, se sim, trazer o commit para cá mantendo o patch do PHN16-72.
5. Para reinstalar depois de corrigir: `./helios-kb.sh --uninstall && ./helios-kb.sh --install`.
6. Funcionou? Acrescente o kernel em [`TESTED_KERNELS`](TESTED_KERNELS) e na tabela dos três READMEs.

Saída de emergência enquanto não corrige: `./helios-kb.sh --uninstall`. Volta o `acer_wmi` do kernel e o resto funciona, só fica sem luz no teclado.

## Pendências

- Abrir PR de uma linha no upstream adicionando `kb_zone_arm = 1` ao PHN16-72.
- Confirmar que a cor volta sozinha depois de um reboot.

## Licença

[GPL-3.0](LICENSE), a mesma do [repositório original](https://github.com/0x7375646F/Linuwu-Sense). O arquivo `LICENSE` é cópia idêntica do upstream. O `src/linuwu_sense.c` mantém o cabeçalho `SPDX-License-Identifier: GPL-2.0-or-later` herdado do `acer-wmi` do kernel, compatível com a GPL-3.0. Os arquivos acrescentados por este fork (`helios-kb.sh`, `TESTED_KERNELS`, READMEs e patch) seguem a mesma GPL-3.0.
