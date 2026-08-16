#!/data/data/com.termux/files/usr/bin/bash
# PC Otimizador Pro — Android via Termux
# Escopo HONESTO: so o ambiente Termux / arquivos que o Termux alcanca.
# Sem root NAO limpa cache de outros apps nem "otimiza o telefone inteiro".
set -u

VERSION="5.5-android-termux"
DRY_RUN=0
AUTO_YES=0
LOG_DIR="${HOME}/.pc-otimizador-logs"
SESSION_LOG=""
FREED_KB=0
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
CANCEL_FILE="${TMPDIR:-/tmp}/pc-otimizador-cancel.flag"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOAD_PRESET="${SCRIPT_DIR}/../core/load_preset.py"

mkdir -p "$LOG_DIR"

log() {
  local level="${2:-INFO}"
  local line="[$(date +%H:%M:%S)] [$level] $1"
  printf '%s\n' "$line"
  [[ -n "$SESSION_LOG" ]] && printf '%s\n' "$line" >>"$SESSION_LOG"
  printf '##LOG##|%s|%s\n' "$level" "$1"
}

progress() {
  local cur="$1" total="$2" name="$3"
  local pct=0
  (( total > 0 )) && pct=$(( cur * 100 / total ))
  printf '##PROGRESS##|%s|%s|%s|%s\n' "$cur" "$total" "$name" "$pct"
  log ">> [$cur/$total] $name"
}

cancel_requested() { [[ -f "$CANCEL_FILE" ]]; }
reset_cancel() { rm -f "$CANCEL_FILE" 2>/dev/null || true; }

kb_of() {
  local p="$1"
  if [[ -d "$p" ]]; then du -sk "$p" 2>/dev/null | awk '{print $1}'; else echo 0; fi
}

human_kb() {
  local kb="$1"
  if (( kb > 1048576 )); then awk -v k="$kb" 'BEGIN{printf "%.2f GB", k/1048576}'
  elif (( kb > 1024 )); then awk -v k="$kb" 'BEGIN{printf "%.1f MB", k/1024}'
  else echo "${kb} KB"; fi
}

safe_clean_dir() {
  local p="$1"
  [[ -e "$p" ]] || return 0
  [[ -L "$p" ]] && { log "Ignorado (symlink): $p" WARN; return 0; }
  case "$p" in
    /data/data/*/files/*|/data/user/0/*/files/*) ;;
    *) log "Alvo recusado: fora do sandbox Termux: $p" WARN; return 0 ;;
  esac
  [[ "$p" == "$HOME" || "$p" == "$PREFIX" ]] && { log "Ignorado (raiz do sandbox): $p" WARN; return 0; }
  case "$p" in
    /sdcard/DCIM*|/sdcard/Download*|/sdcard/Pictures*|/storage/*/DCIM*|/storage/*/Download*)
      log "Protegido (midia/downloads): $p" WARN; return 0 ;;
  esac
  local kb; kb="$(kb_of "$p")"
  if (( DRY_RUN == 1 )); then
    log "[DRY-RUN] Limparia $p (~$(human_kb "$kb"))"
    FREED_KB=$((FREED_KB + kb)); return 0
  fi
  if [[ -d "$p" ]]; then
    find "$p" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
  else
    rm -f "$p" 2>/dev/null || true
  fi
  local after delta
  after="$(kb_of "$p")"
  delta=$(( kb - after )); (( delta < 0 )) && delta=0
  FREED_KB=$((FREED_KB + delta))
  log "Limpo: $p (~$(human_kb "$delta"))"
}

init_log() {
  SESSION_LOG="${LOG_DIR}/sessao-$(date +%Y%m%d-%H%M%S).txt"
  {
    echo "PC Otimizador Termux $VERSION"
    echo "Inicio: $(date)"
    echo "DryRun: $DRY_RUN | HOME=$HOME"
    echo "----------------------------------------"
  } >"$SESSION_LOG"
}

finish_log() {
  echo "----------------------------------------" >>"$SESSION_LOG"
  echo "Liberado~$(human_kb "$FREED_KB")" >>"$SESSION_LOG"
  echo "Fim: $(date)" >>"$SESSION_LOG"
  log "Log: $SESSION_LOG"
  printf '##DONE##|ok|%s\n' "$(human_kb "$FREED_KB")"
}

act_termux_cache() {
  safe_clean_dir "${HOME}/.cache"
  safe_clean_dir "${PREFIX}/tmp"
  safe_clean_dir "${PREFIX}/var/cache"
}

act_apt() {
  if ! command -v apt >/dev/null; then return 0; fi
  if (( DRY_RUN == 1 )); then log "[DRY-RUN] apt clean && autoremove"; return 0; fi
  apt clean 2>/dev/null || true
  log "apt clean"
}

act_pip() {
  if command -v pip >/dev/null; then
    if (( DRY_RUN == 1 )); then log "[DRY-RUN] pip cache purge"; return 0; fi
    pip cache purge 2>/dev/null || true
  fi
  if command -v npm >/dev/null; then
    if (( DRY_RUN == 1 )); then log "[DRY-RUN] npm cache clean --force"; return 0; fi
    npm cache clean --force 2>/dev/null || true
  fi
}

act_tips() {
  log "Dica Android (sem root): Ajustes > Armazenamento > Liberar espaco"
  log "Dica: limpe cache por app em Ajustes > Apps > [app] > Armazenamento"
  log "Este script NAO remove fotos/WhatsApp/Downloads do /sdcard."
}

preset_ids() {
  local name="${1:-safe}"
  if command -v python3 >/dev/null 2>&1 && [[ -f "$LOAD_PRESET" ]]; then
    local out
    out="$(python3 "$LOAD_PRESET" android_termux "$name" 2>/dev/null || true)"
    if [[ -n "$out" ]]; then echo "$out"; return 0; fi
  fi
  echo "termux_cache apt pip"
}

run_action() {
  case "$1" in
    termux_cache) act_termux_cache ;;
    apt) act_apt ;;
    pip) act_pip ;;
    *) log "Acao desconhecida: $1" WARN ;;
  esac
}

run_safe() {
  FREED_KB=0
  reset_cancel
  init_log
  log "Escopo: apenas Termux (sandbox). Sem root = sem limpeza global do Android."
  local ids=( $(preset_ids safe) )
  local total=${#ids[@]} i=0 id
  local cancelled=0
  for id in "${ids[@]}"; do
    if cancel_requested; then
      log "Cancelado pelo usuario" WARN
      cancelled=1
      break
    fi
    i=$((i + 1))
    progress "$i" "$total" "$id"
    run_action "$id"
  done
  act_tips
  finish_log
  if (( cancelled == 1 )); then printf '##DONE##|cancelled\n'; return 2; fi
  log "Concluido. Liberado~$(human_kb "$FREED_KB")"
}

confirm() {
  (( AUTO_YES == 1 )) && return 0
  printf '  %s [s/N]: ' "$1"
  read -r r || true
  [[ "$r" == s || "$r" == S || "$r" == y || "$r" == Y ]]
}

banner() {
  clear 2>/dev/null || true
  echo
  echo "  ============================================================"
  echo "       PC OTIMIZADOR  ·  Android/Termux $VERSION"
  echo "  ============================================================"
  echo "  Escopo realista: limpa o Termux, nao o Android inteiro."
  echo "  Cancel: touch \$TMPDIR/pc-otimizador-cancel.flag"
  echo "  Logs: $LOG_DIR"
  echo
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y) AUTO_YES=1; shift ;;
    --preset) [[ $# -ge 2 ]] && shift 2 || { echo 'Falta valor para --preset' >&2; exit 2; } ;;
    --help|-h) echo "Uso: $0 [--dry-run] [--yes]"; exit 0 ;;
    *) shift ;;
  esac
done

if (( AUTO_YES == 1 )); then
  run_safe; exit $?
fi

while true; do
  banner
  echo "   1. Limpeza Segura Termux ★"
  echo "   2. Dry-run"
  echo "   3. Dicas Android (sem root)"
  echo "   0. Sair"
  printf '  Opcao > '; read -r op || true
  case "$op" in
    1) confirm "Limpar caches do Termux?" && { DRY_RUN=0; run_safe; printf '\n  Enter...'; read -r _; } ;;
    2) DRY_RUN=1; run_safe; DRY_RUN=0; printf '\n  Enter...'; read -r _ ;;
    3) act_tips; printf '\n  Enter...'; read -r _ ;;
    0|q|Q) exit 0 ;;
  esac
done
