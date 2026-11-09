#!/usr/bin/env bash
# helios-kb.sh - atalhos para build, teste, instalação e uso do Linuwu-Sense
# no Acer Predator Helios Neo 16 (PHN16-72). Ver README.md.
# Licença / License: GPL-3.0, a mesma do upstream (ver LICENSE).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD=linuwu_sense
KO="$REPO/src/$MOD.ko"
SRC="$REPO/src/$MOD.c"
BASE="/sys/module/$MOD/drivers/platform:acer-wmi/acer-wmi"
KB="$BASE/four_zoned_kb"
TESTED_MODEL="Predator PHN16-72"
KVER="${KVER:-$(uname -r)}"
DEPS=(wmi sparse-keymap hid video)
TESTED_FILE="$REPO/TESTED_KERNELS"
UPSTREAM="https://github.com/0x7375646F/Linuwu-Sense"
ASSUME_YES="${HELIOS_KB_ACCEPT_RISK:-0}"

# ---------- saída ----------
if [[ -t 1 ]]; then C_OK=$'\e[32m'; C_WARN=$'\e[33m'; C_ERR=$'\e[31m'; C_B=$'\e[1m'; C_0=$'\e[0m'
else C_OK=; C_WARN=; C_ERR=; C_B=; C_0=; fi
step() { printf '%s==>%s %s\n' "$C_B" "$C_0" "$*"; }
ok()   { printf '  %s✔%s %s\n' "$C_OK" "$C_0" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_WARN" "$C_0" "$*"; }
die()  { printf '  %s✘%s %s\n' "$C_ERR" "$C_0" "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Uso: ./helios-kb.sh <comando> [args]

Build e instalação
  --make [--kver X]      compila src/$MOD.ko (kernel atual ou X; também via KVER=X)
  --smoke-test           carrega o build local SEM instalar e testa o RGB (um reboot desfaz)
  --install              instala via DKMS (sudo make install) e confere o resultado
  --uninstall            remove tudo (sudo make uninstall) e volta o acer_wmi
  --restore              descarrega o $MOD e recarrega o acer_wmi (só até o próximo boot)
  --clean                apaga os artefatos de build

Diagnóstico
  --status               modelo, kernel, módulo carregado, DKMS, serviço e estado do teclado
  --check-patch          confere se o quirk kb_zone_arm do PHN16-72 está no fonte

Teclado
  --color HEX [HEX HEX HEX] [BRILHO]   cor fixa: 1 cor = todas as zonas; brilho 0-100 (padrão 100)
  --effect MODO [VEL] [BRILHO] [DIR] [HEX]
                         MODO: static|breathing|neon|wave|shifting|zoom|0-7
                         VEL 0-9 (4), BRILHO 0-100 (100), DIR 1-2 (1), HEX cor (0000ff)
  --off                  apaga o teclado (brilho 0, cores mantidas)

Opções
  --yes, -y              aceita o aviso de risco sem perguntar (também: HELIOS_KB_ACCEPT_RISK=1)

Exemplos
  ./helios-kb.sh --make --kver 7.1.0-10-generic   # testar kernel novo antes do reboot
  ./helios-kb.sh --color 4287f5
  ./helios-kb.sh --color ff0000 00ff00 0000ff ffffff 60
  ./helios-kb.sh --effect wave 5
EOF
}

# ---------- helpers ----------
need_sudo() { sudo -v || die "sem sudo, sem brincadeira"; }

is_loaded() { [[ -d "/sys/module/$1" ]]; }

model() { cat /sys/class/dmi/id/product_name 2>/dev/null || echo "?"; }

check_model() {
  local m; m="$(model)"
  if [[ "$m" == "$TESTED_MODEL" ]]; then ok "modelo: $m"
  else warn "modelo: '$m' (testado só no '$TESTED_MODEL'; siga por sua conta)"; fi
}

# Extrai o bloco do quirk do PHN16-72 e procura kb_zone_arm.
patch_applied() {
  awk '/quirk_entry quirk_acer_predator_phn16_72 = \{/,/\};/' "$SRC" | grep -q 'kb_zone_arm *= *1'
}

check_patch() {
  if patch_applied; then ok "patch PHN16-72 (kb_zone_arm) presente"
  else die "patch PHN16-72 ausente no fonte. Aplicar: git apply patches/0001-phn16-72-kb-zone-arm.patch"; fi
}

ko_vermagic() { modinfo -F vermagic "$KO" 2>/dev/null | awk '{print $1}'; }

ko_fresh_for() {
  [[ -f "$KO" && "$(ko_vermagic)" == "$1" && "$KO" -nt "$SRC" ]]
}

# Escreve no sysfs direto (grupo linuwu_sense) ou via sudo.
sysfs_write() {
  local file="$1" value="$2"
  [[ -e "$file" ]] || die "não existe: $file (o $MOD está carregado?)"
  if [[ -w "$file" ]]; then printf '%s\n' "$value" > "$file"
  else printf '%s\n' "$value" | sudo tee "$file" > /dev/null; fi
}

# Lê do sysfs direto ou via sudo (após o install os arquivos ficam 0660 root:linuwu_sense).
sysfs_read() {
  if [[ -r "$1" ]]; then tr -d '\n' < "$1"
  else sudo cat "$1" | tr -d '\n'; fi
}

require_kb() {
  is_loaded "$MOD" || die "$MOD não está carregado. Rode --smoke-test ou --install."
  [[ -d "$KB" ]] || die "$KB não existe. O módulo carregou sem four_zone_kb para este modelo."
}

hex_ok() { [[ "$1" =~ ^[0-9a-fA-F]{6}$ ]]; }
num_in() { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= $2 && $1 <= $3 )); }

wait_for() { local i; for i in $(seq 1 "${2:-20}"); do [[ -e "$1" ]] && return 0; sleep 0.25; done; return 1; }

# ---------- comandos ----------
cmd_make() {
  step "Build para o kernel $KVER"
  [[ -d "/lib/modules/$KVER/build" ]] \
    || die "headers ausentes: sudo apt install linux-headers-$KVER"
  check_patch
  local log; log="$(mktemp)"
  if ! make -C "/lib/modules/$KVER/build" M="$REPO" modules >"$log" 2>&1; then
    grep -E 'error|Error' "$log" | head -30 >&2 || true
    warn "log completo: $log"
    die "build falhou para $KVER"
  fi
  grep -qE 'compiler differs|pahole|Skipping BTF' "$log" \
    && warn "avisos de compiler/pahole/BTF: inofensivos (ver README)"
  rm -f "$log"
  [[ "$(ko_vermagic)" == "$KVER" ]] || die "vermagic do .ko ($(ko_vermagic)) não bate com $KVER"
  ok "build ok: $KO ($KVER)"
}

cmd_smoke_test() {
  [[ "$KVER" == "$(uname -r)" ]] || die "--smoke-test só roda no kernel em execução ($(uname -r))"
  step "Smoke test (temporário; um reboot desfaz)"
  check_model
  ko_fresh_for "$KVER" || cmd_make
  need_sudo

  if is_loaded "$MOD"; then
    warn "$MOD já carregado ($(modinfo -n $MOD 2>/dev/null || echo insmod)); trocando pelo build local"
    sudo rmmod "$MOD"
  fi
  sudo modprobe -a "${DEPS[@]}"
  is_loaded acer_wmi && { sudo rmmod acer_wmi; ok "acer_wmi descarregado"; }

  if ! sudo insmod "$KO"; then
    warn "insmod falhou; recarregando acer_wmi"
    sudo modprobe acer_wmi || true
    sudo dmesg | grep -E "$MOD|acer" | tail -15 >&2
    die "módulo não carregou"
  fi
  ok "$MOD carregado (build local)"

  wait_for "$KB/per_zone_mode" || die "four_zoned_kb não apareceu em $BASE"
  ok "sysfs: four_zoned_kb presente"
  [[ -d "$BASE/predator_sense" ]] && ok "sysfs: predator_sense presente" || warn "predator_sense ausente"

  local test="ff0000,00ff00,0000ff,ffffff,100"
  sysfs_write "$KB/per_zone_mode" "$test"
  local got; got="$(sysfs_read "$KB/per_zone_mode")"
  [[ "${got,,}" == "$test" ]] && ok "per_zone_mode lido de volta: $got" || warn "per_zone_mode leu '$got' (esperado $test)"

  if sudo dmesg | tail -50 | grep -E "$MOD.*(fail|error|Error)"; then warn "erros acima no dmesg"
  else ok "dmesg sem erros do $MOD"; fi

  if [[ -t 0 ]]; then
    local ans
    read -rp "  O teclado acendeu em vermelho/verde/azul/branco (esq→dir)? [s/N] " ans
    if [[ "${ans,,}" == s* ]]; then
      ok "smoke test passou. Próximo passo: ./helios-kb.sh --install"
    else
      warn "falhou visualmente. Plano B: ./helios-kb.sh --effect wave (efeito animado) e veja o README"
      warn "para voltar ao original: ./helios-kb.sh --restore"
      exit 1
    fi
  else
    ok "sysfs ok. Confira o teclado visualmente."
  fi
}

cmd_install() {
  step "Instalação via DKMS"
  check_model
  check_patch
  command -v dkms >/dev/null || die "dkms ausente: sudo apt install dkms"
  ko_fresh_for "$KVER" || cmd_make   # falha cedo, antes de mexer no sistema
  need_sudo
  (cd "$REPO" && sudo make install)

  step "Conferindo"
  dkms status "$MOD" | sed 's/^/  /'
  local path; path="$(modinfo -n "$MOD" 2>/dev/null || true)"
  [[ "$path" == *updates/dkms* ]] && ok "módulo do DKMS: $path" || warn "modinfo aponta para '$path'"
  is_loaded "$MOD" && ok "$MOD carregado" || die "$MOD não está carregado"
  wait_for "$KB/per_zone_mode" && ok "four_zoned_kb presente" || die "four_zoned_kb ausente"
  systemctl is-enabled --quiet linuwu_sense.service && ok "linuwu_sense.service habilitado" || warn "serviço não habilitado"
  id -nG | grep -qw "$MOD" || warn "faça logout/login para o grupo $MOD valer (sysfs sem sudo)"
  ok "instalado. Para testar o boot, reinicie e rode: ./helios-kb.sh --status"
}

cmd_uninstall() {
  step "Desinstalando"
  need_sudo
  (cd "$REPO" && sudo make uninstall)
  is_loaded acer_wmi && ok "acer_wmi de volta" || warn "acer_wmi não carregou"
}

cmd_restore() {
  step "Voltando ao acer_wmi (temporário)"
  need_sudo
  is_loaded "$MOD" && sudo rmmod "$MOD"
  sudo modprobe acer_wmi
  ok "acer_wmi carregado"
  [[ -f /etc/modprobe.d/blacklist-acer_wmi.conf ]] \
    && warn "instalação DKMS presente: no próximo boot volta o $MOD (use --uninstall para remover)"
}

cmd_clean() {
  make -C "/lib/modules/$KVER/build" M="$REPO" clean >/dev/null
  ok "build limpo"
}

cmd_status() {
  step "Sistema"
  check_model
  printf '  BIOS: %s | kernel: %s\n' "$(cat /sys/class/dmi/id/bios_version 2>/dev/null)" "$(uname -r)"
  if mokutil --sb-state 2>/dev/null | head -1 | grep -q enabled; then
    printf '  %s\n' "$(mokutil --sb-state 2>/dev/null | tr '\n' ';')"
  fi

  step "Módulos"
  if is_loaded "$MOD"; then
    local p; p="$(modinfo -n "$MOD" 2>/dev/null || true)"
    if [[ "$(cat /sys/module/$MOD/srcversion 2>/dev/null)" == "$(modinfo -F srcversion "$KO" 2>/dev/null)" ]] && [[ -f "$KO" ]]; then
      ok "$MOD carregado (build local deste repo)"
    else
      ok "$MOD carregado (${p:-origem desconhecida})"
    fi
  else
    warn "$MOD não carregado"
  fi
  is_loaded acer_wmi && warn "acer_wmi carregado (sem RGB)" || ok "acer_wmi não carregado"
  [[ -f /etc/modprobe.d/blacklist-acer_wmi.conf ]] && ok "acer_wmi na blacklist" || warn "sem blacklist (não instalado)"

  step "DKMS / serviço"
  if command -v dkms >/dev/null && dkms status "$MOD" 2>/dev/null | grep -q .; then
    dkms status "$MOD" | sed 's/^/  /'
    dkms status "$MOD" | grep -q "$(uname -r).*installed" \
      || warn "DKMS sem build instalado para $(uname -r): veja /var/lib/dkms/$MOD/*/build/make.log"
  else
    warn "não instalado via DKMS"
  fi
  systemctl is-enabled --quiet linuwu_sense.service 2>/dev/null \
    && ok "linuwu_sense.service: $(systemctl is-active linuwu_sense.service)" || warn "linuwu_sense.service não habilitado"
  id -nG | grep -qw "$MOD" && ok "usuário no grupo $MOD" || warn "usuário fora do grupo $MOD (sysfs só com sudo)"

  step "Fonte"
  patch_applied && ok "patch PHN16-72 presente" || warn "patch PHN16-72 AUSENTE"

  step "Teclado"
  if [[ -d "$KB" ]]; then
    printf '  per_zone_mode:  %s\n' "$(sysfs_read "$KB/per_zone_mode")"
    printf '  four_zone_mode: %s\n' "$(sysfs_read "$KB/four_zone_mode")"
  else
    warn "four_zoned_kb indisponível"
  fi
}

cmd_color() {
  require_kb
  local -a cols=() ; local bright=100
  for a in "$@"; do
    a="${a#\#}"
    if hex_ok "$a"; then cols+=("${a,,}")
    elif num_in "$a" 0 100; then bright="$a"
    else die "argumento inválido: '$a' (HEX RRGGBB ou brilho 0-100)"; fi
  done
  case "${#cols[@]}" in
    1) cols=("${cols[0]}" "${cols[0]}" "${cols[0]}" "${cols[0]}") ;;
    4) ;;
    *) die "passe 1 ou 4 cores" ;;
  esac
  local v; v="$(IFS=,; echo "${cols[*]}"),$bright"
  sysfs_write "$KB/per_zone_mode" "$v"
  ok "per_zone_mode = $v"
}

cmd_effect() {
  require_kb
  local mode="${1:-}"; [[ -n "$mode" ]] || die "informe o modo"
  case "${mode,,}" in
    static) mode=0 ;; breathing) mode=1 ;; neon) mode=2 ;; wave) mode=3 ;;
    shifting) mode=4 ;; zoom) mode=5 ;;
  esac
  local speed="${2:-4}" bright="${3:-100}" dir="${4:-1}" hex="${5:-0000ff}"
  hex="${hex#\#}"
  num_in "$mode" 0 7 || die "modo inválido"
  num_in "$speed" 0 9 || die "velocidade 0-9"
  num_in "$bright" 0 100 || die "brilho 0-100"
  num_in "$dir" 1 2 || die "direção 1-2"
  hex_ok "$hex" || die "cor RRGGBB"
  [[ "$mode" == 0 ]] && warn "no PHN16-72 o modo 0 via four_zone_mode apaga o teclado; para cor fixa use --color"
  local v="$mode,$speed,$bright,$dir,$((16#${hex:0:2})),$((16#${hex:2:2})),$((16#${hex:4:2}))"
  sysfs_write "$KB/four_zone_mode" "$v"
  ok "four_zone_mode = $v"
}

cmd_off() {
  require_kb
  local cur; cur="$(sysfs_read "$KB/per_zone_mode")"
  sysfs_write "$KB/per_zone_mode" "${cur%,*},0"
  ok "teclado apagado (volte com --color ... 100)"
}

# ---------- disclaimer ----------
tested_kernels() { [[ -f "$TESTED_FILE" ]] && grep -vE '^\s*(#|$)' "$TESTED_FILE" | cut -d'|' -f1 | tr -d ' '; }

# Banner em inglês, colorido e piscando, a cada execução (vai para stderr).
banner() {
  local R= Y= W= BL= B= Z=
  if [[ -t 2 ]]; then R=$'\e[31m'; Y=$'\e[33m'; W=$'\e[97m'; BL=$'\e[5m'; B=$'\e[1m'; Z=$'\e[0m'; fi
  local k tested=0 list=""
  while read -r k; do [[ -n "$k" ]] || continue; list+="    • $k"$'\n'; [[ "$k" == "$(uname -r)" ]] && tested=1; done < <(tested_kernels)
  {
    printf '%s\n' "${R}${B}${BL}  ⚠  WARNING · READ BEFORE USING  ⚠${Z}"
    printf '%s\n' "${Y}${B}  This repository is a copy of the original Linuwu-Sense branch${Z}"
    printf '%s\n' "${Y}  ($UPSTREAM)${Z}"
    printf '%s\n' "${Y}  with a single change to make the keyboard RGB work on MY laptop:${Z}"
    printf '%s\n' "${Y}  Acer Predator Helios Neo 16 (PHN16-72).${Z}"
    printf '\n'
    printf '%s\n' "${R}${B}${BL}  • NO WARRANTY that it will work on yours.${Z}"
    printf '%s\n' "${R}${B}${BL}  • I am NOT RESPONSIBLE for any damage to your notebook.${Z}"
    printf '\n'
    printf '%s\n' "${W}  Nothing here should harm your laptop, but it replaces the kernel's${Z}"
    printf '%s\n' "${W}  acer_wmi driver with an unofficial module. Use at your own risk.${Z}"
    printf '%s\n' "${W}  Kernels I have tested (updated as I upgrade):${Z}"
    printf '%s' "${W}${list:-    (none listed)$'\n'}${Z}"
    if (( tested )); then printf '%s\n' "${Y}  Running kernel $(uname -r): tested ✔${Z}"
    else printf '%s\n' "${R}${B}${BL}  Running kernel $(uname -r): NOT TESTED${Z}"; fi
    printf '\n'
  } >&2
}

# Pede "Y" antes de qualquer comando que troque módulo do kernel.
confirm_risk() {
  [[ "$ASSUME_YES" == 1 ]] && { warn "risk accepted via --yes / HELIOS_KB_ACCEPT_RISK=1"; return 0; }
  [[ -t 0 ]] || die "non-interactive session: re-run with --yes to accept the risks"
  local ans
  read -rp "  Type Y to confirm \"I understand the risks\": " ans
  [[ "$ans" == Y || "$ans" == y ]] || die "aborted. Nothing was changed."
}

# ---------- main ----------
args=()
for a in "$@"; do
  if [[ "$a" == --yes || "$a" == -y ]]; then ASSUME_YES=1; else args+=("$a"); fi
done
set -- "${args[@]+"${args[@]}"}"

banner
[[ $# -gt 0 ]] || { usage; exit 1; }
cmd="$1"; shift
if [[ "${1:-}" == "--kver" ]]; then KVER="${2:?--kver precisa de valor}"; shift 2; fi

case "$cmd" in
  --make)         cmd_make ;;
  --smoke-test)   confirm_risk; cmd_smoke_test ;;
  --install)      confirm_risk; cmd_install ;;
  --uninstall)    cmd_uninstall ;;
  --restore)      cmd_restore ;;
  --clean)        cmd_clean ;;
  --status)       cmd_status ;;
  --check-patch)  check_patch ;;
  --color)        cmd_color "$@" ;;
  --effect)       cmd_effect "$@" ;;
  --off)          cmd_off ;;
  -h|--help)      usage ;;
  *)              usage; exit 1 ;;
esac
