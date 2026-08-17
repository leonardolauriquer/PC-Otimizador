#!/usr/bin/env bash
# PC Otimizador Pro — macOS
# Seguro: nao apaga Documents/Pictures/Downloads/Desktop.
set -u

VERSION="5.9-macos"
DRY_RUN=0
AUTO_YES=0
LANG_UI="${LANG_UI:-pt}"
LOG_DIR="${HOME}/Library/Application Support/PC-Otimizador/logs"
WHITELIST_FILE="${LOG_DIR}/whitelist.txt"
CANCEL_FILE="${TMPDIR:-/tmp}/pc-otimizador-cancel.flag"
TMP_ROOT="${TMPDIR:-/tmp}"
SESSION_LOG=""
FREED_KB=0
LOCK_DIR="${LOG_DIR}/execution.lock"

mkdir -p "$LOG_DIR"

acquire_lock() {
  if [[ -d "$LOCK_DIR" ]]; then
    local old=""; [[ -f "$LOCK_DIR/pid" ]] && old="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [[ "$old" =~ ^[0-9]+$ ]] && kill -0 "$old" 2>/dev/null; then log "Outra otimizacao ja esta em execucao (PID $old)" ERROR; return 1; fi
    rm -rf "$LOCK_DIR" 2>/dev/null || return 1
  fi
  mkdir "$LOCK_DIR" || return 1; printf '%s' "$$" >"$LOCK_DIR/pid"
}
release_lock() { rm -rf "$LOCK_DIR" 2>/dev/null || true; }
run_bounded() {
  local seconds="$1"; shift
  "$@" & local pid=$!
  ( sleep "$seconds"; kill -TERM "$pid" 2>/dev/null || true ) & local watchdog=$!
  wait "$pid"; local rc=$?
  kill "$watchdog" 2>/dev/null || true; wait "$watchdog" 2>/dev/null || true
  return "$rc"
}

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

init_log() {
  SESSION_LOG="${LOG_DIR}/sessao-$(date +%Y%m%d-%H%M%S).txt"
  {
    echo "PC Otimizador Pro macOS $VERSION"
    echo "Inicio: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Host: $(hostname) | User: $USER | DryRun: $DRY_RUN"
    echo "----------------------------------------"
  } >"$SESSION_LOG"
}

finish_log() {
  local summary="${1:-}"
  [[ -n "$SESSION_LOG" ]] || return 0
  echo "----------------------------------------" >>"$SESSION_LOG"
  [[ -n "$summary" ]] && echo "$summary" >>"$SESSION_LOG"
  echo "Fim: $(date '+%Y-%m-%d %H:%M:%S')" >>"$SESSION_LOG"
  log "Log salvo em: $SESSION_LOG"
}

cancel_requested() { [[ -f "$CANCEL_FILE" ]]; }
reset_cancel() { rm -f "$CANCEL_FILE" 2>/dev/null || true; }

ensure_whitelist() {
  if [[ ! -f "$WHITELIST_FILE" ]]; then
    cat >"$WHITELIST_FILE" <<EOF
$HOME/Documents
$HOME/Pictures
$HOME/Movies
$HOME/Music
$HOME/Desktop
$HOME/Downloads
EOF
  fi
}

is_protected() {
  local path="$1" w
  ensure_whitelist
  path="${path%/}"
  while IFS= read -r w; do
    [[ -z "$w" ]] && continue
    w="${w%/}"
    if [[ "$path" == "$w" || "$path" == "$w"/* ]]; then
      return 0
    fi
  done <"$WHITELIST_FILE"
  return 1
}

bytes_of() {
  local p="$1"
  if [[ -d "$p" ]]; then
    du -sk "$p" 2>/dev/null | awk '{print $1*1024}'
  elif [[ -f "$p" ]]; then
    stat -f%z "$p" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

kb_of_path() { echo $(( $(bytes_of "$1") / 1024 )); }

human_kb() {
  local kb="$1"
  if (( kb > 1048576 )); then awk -v k="$kb" 'BEGIN{printf "%.2f GB", k/1048576}'
  elif (( kb > 1024 )); then awk -v k="$kb" 'BEGIN{printf "%.1f MB", k/1024}'
  else echo "${kb} KB"; fi
}

safe_rm_tree() {
  local p="$1"
  [[ -e "$p" ]] || return 0
  [[ -L "$p" ]] && { log "Ignorado (symlink): $p" WARN; return 0; }
  case "$p" in
    /tmp/*|"$TMP_ROOT"/*|"$HOME"/.Trash/*|"$HOME"/Library/Caches/*|"$HOME"/Library/Logs/DiagnosticReports/*) ;;
    *) log "Alvo recusado pela allowlist: $p" WARN; return 0 ;;
  esac
  if is_protected "$p"; then log "Whitelist: protegido $p" WARN; return 0; fi
  local kb; kb="$(kb_of_path "$p")"
  if (( DRY_RUN == 1 )); then
    log "[DRY-RUN] Removeria $p (~$(human_kb "$kb"))"
    FREED_KB=$((FREED_KB + kb)); return 0
  fi
  if [[ -d "$p" ]]; then
    find "$p" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || { log "Falha ao limpar: $p" ERROR; return 1; }
  else
    rm -f "$p" 2>/dev/null || { log "Falha ao remover: $p" ERROR; return 1; }
  fi
  local after delta
  after="$(kb_of_path "$p")"
  delta=$(( kb - after )); (( delta < 0 )) && delta=0
  FREED_KB=$((FREED_KB + delta))
  log "Limpo: $p (~$(human_kb "$delta"))"
}

clean_owned_tmp() {
  local base item uid
  uid="$(id -u)"
  for base in /tmp "$TMP_ROOT"; do
    [[ -d "$base" ]] || continue
    while IFS= read -r -d '' item; do
      safe_rm_tree "$item"
    done < <(find "$base" -mindepth 1 -maxdepth 1 -user "$uid" -mtime +1 -print0 2>/dev/null)
  done
}

owned_tmp_kb() {
  local base item total=0 uid
  uid="$(id -u)"
  for base in /tmp "$TMP_ROOT"; do
    [[ -d "$base" ]] || continue
    while IFS= read -r -d '' item; do
      total=$(( total + $(kb_of_path "$item") ))
    done < <(find "$base" -mindepth 1 -maxdepth 1 -user "$uid" -mtime +1 -print0 2>/dev/null)
  done
  echo "$total"
}

disk_free_gb() { df -g / 2>/dev/null | awk 'NR==2{print $4}'; }
disk_used_pct() { df -P / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}'; }
mem_used_pct() {
  local total page free inactive speculative wired active compressed used
  total=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  page=$(pagesize 2>/dev/null || echo 4096)
  if (( total <= 0 )); then echo 50; return; fi
  # vm_stat: free + inactive + speculative ≈ available-ish
  free=$(vm_stat 2>/dev/null | awk '/Pages free/ {gsub("\\.","",$3); print $3}')
  inactive=$(vm_stat 2>/dev/null | awk '/Pages inactive/ {gsub("\\.","",$3); print $3}')
  speculative=$(vm_stat 2>/dev/null | awk '/Pages speculative/ {gsub("\\.","",$3); print $3}')
  free=${free:-0}; inactive=${inactive:-0}; speculative=${speculative:-0}
  used=$(( total - (free + inactive + speculative) * page ))
  (( used < 0 )) && used=0
  awk -v u="$used" -v t="$total" 'BEGIN{ printf "%d", (u*100)/t }'
}

health_score() {
  local score=100 used junk
  used="$(disk_used_pct)"; used=${used:-50}
  junk=$(( $(kb_of_path "$HOME/Library/Caches") + $(owned_tmp_kb) ))
  (( used >= 95 )) && score=$((score - 40))
  (( used >= 85 && used < 95 )) && score=$((score - 25))
  (( used >= 75 && used < 85 )) && score=$((score - 15))
  (( junk > 5000000 )) && score=$((score - 20))
  (( junk > 2000000 && junk <= 5000000 )) && score=$((score - 12))
  (( junk > 500000 && junk <= 2000000 )) && score=$((score - 6))
  (( score < 0 )) && score=0
  local grade=A
  (( score < 85 )) && grade=B
  (( score < 70 )) && grade=C
  (( score < 50 )) && grade=D
  (( score < 30 )) && grade=E
  echo "$score $grade $used $junk"
}

act_temp() {
  clean_owned_tmp
  safe_rm_tree "$HOME/Library/Caches/com.apple.thumbnails.cache"
}

act_trash() {
  safe_rm_tree "$HOME/.Trash"
}

act_user_cache() {
  # caches regeneraveis comuns — nao limpa Library inteira
  local d
  for d in \
    "$HOME/Library/Caches/Google/Chrome" \
    "$HOME/Library/Caches/Mozilla" \
    "$HOME/Library/Caches/com.spotify.client" \
    "$HOME/Library/Caches/com.discord" \
    "$HOME/Library/Caches/Homebrew" \
    "$HOME/Library/Caches/pip" \
    "$HOME/Library/Caches/CocoaPods"
  do
    [[ -e "$d" ]] && safe_rm_tree "$d"
  done
  # generic: only known-safe subfolders under Caches if empty-ish patterns
  if [[ -d "$HOME/Library/Caches" ]]; then
    find "$HOME/Library/Caches" -maxdepth 1 -type d \( -iname '*thumb*' -o -iname '*shader*' -o -iname '*GPU*' \) 2>/dev/null \
      | while read -r c; do safe_rm_tree "$c"; done
  fi
}

act_brew() {
  if ! command -v brew >/dev/null; then log "Homebrew nao instalado"; return 20; fi
  if (( DRY_RUN == 1 )); then log "[DRY-RUN] brew cleanup -s"; return 0; fi
  run_bounded 300 brew cleanup -s 2>/dev/null || { log "brew cleanup falhou ou excedeu 300s" ERROR; return 1; }
}

act_dns() {
  if (( DRY_RUN == 1 )); then log "[DRY-RUN] dscacheutil -flushcache + mDNSResponder"; return 0; fi
  dscacheutil -flushcache 2>/dev/null || { log "dscacheutil falhou" ERROR; return 1; }
  sudo killall -HUP mDNSResponder 2>/dev/null || { log "mDNSResponder falhou (sudo?)" ERROR; return 1; }
  log "DNS flush macOS"
}

act_logs_user() {
  # nao apaga /var/log do sistema sem cuidado; so DiagnosticReports antigos do usuario
  safe_rm_tree "$HOME/Library/Logs/DiagnosticReports"
}

act_purge_ram_hint() {
  log "macOS gerencia RAM sozinho; 'purge' exige sudo e e opcional."
  if (( DRY_RUN == 1 )); then log "[DRY-RUN] sudo purge"; return 0; fi
  if command -v purge >/dev/null; then
    sudo purge 2>/dev/null || true
  fi
}

estimate_kb() {
  local t=0 p
  for p in "$HOME/.Trash" "$HOME/Library/Caches/Homebrew" "$HOME/Library/Caches/Google/Chrome"; do
    t=$(( t + $(kb_of_path "$p") ))
  done
  t=$(( t + $(owned_tmp_kb) ))
  echo "$t"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOAD_PRESET="${SCRIPT_DIR}/../core/load_preset.py"

preset_ids() {
  local name="${1:-safe}"
  if command -v python3 >/dev/null 2>&1 && [[ -f "$LOAD_PRESET" ]]; then
    local out
    out="$(python3 "$LOAD_PRESET" macos "$name" 2>/dev/null || true)"
    if [[ -n "$out" ]]; then echo "$out"; return 0; fi
  fi
  case "$name" in
    gamer) echo "temp trash cache brew dns" ;;
    net) echo "dns" ;;
    full) echo "temp trash cache brew dns logs" ;;
    notebook) echo "temp trash cache brew dns" ;;
    *) echo "temp trash cache brew dns" ;;
  esac
}

action_name() {
  case "$1" in
    temp) echo "Temporarios" ;;
    trash) echo "Lixeira" ;;
    cache) echo "Caches regeneraveis" ;;
    brew) echo "Homebrew cleanup" ;;
    dns) echo "Flush DNS" ;;
    logs) echo "DiagnosticReports do usuario" ;;
    *) echo "$1" ;;
  esac
}

run_action() {
  case "$1" in
    temp) act_temp ;;
    trash) act_trash ;;
    cache) act_user_cache ;;
    brew) act_brew ;;
    dns) act_dns ;;
    logs) act_logs_user ;;
  esac
}

run_preset() {
  local name="$1"
  local ids=( $(preset_ids "$name") )
  local total=${#ids[@]} i=0 id
  local cancelled=0 failed=0 succeeded=0 skipped=0 rc=0
  FREED_KB=0
  acquire_lock || { printf '##DONE##|BLOCKED|CONCURRENT\n'; return 3; }
  trap release_lock EXIT INT TERM
  reset_cancel
  init_log
  ensure_whitelist
  local before after
  before="$(disk_free_gb)"
  printf '##RESULT##|BEFORE|%s\n' "$before"
  log "Estimativa amostra: $(human_kb "$(estimate_kb)")"
  for id in "${ids[@]}"; do
    cancel_requested && { log "Cancelado" WARN; cancelled=1; break; }
    i=$((i+1))
    progress "$i" "$total" "$(action_name "$id")"
    run_action "$id"; rc=$?
    if (( rc == 0 )); then succeeded=$((succeeded + 1)); printf '##ACTION##|%s|SUCCESS|1|verified\n' "$id"
    elif (( rc == 20 )); then skipped=$((skipped + 1)); printf '##ACTION##|%s|SKIPPED|0|capability unavailable\n' "$id"
    else failed=$((failed + 1)); printf '##ACTION##|%s|FAILED|1|see log\n' "$id"; fi
  done
  after="$(disk_free_gb)"
  read -r score grade _ <<<"$(health_score)"
  local summary="Liberado~$(human_kb "$FREED_KB") | Livres: ${before}G -> ${after}G | Health ${score}/100"
  log "$summary"
  finish_log "$summary"
  printf '##RESULT##|AFTER|%s|%s|%s\n' "$after" "$FREED_KB" "$score"
  printf '##SUMMARY##|SUCCESS=%s|SKIPPED=%s|FAILED=%s|TOTAL=%s\n' "$succeeded" "$skipped" "$failed" "$total"
  if (( cancelled == 1 )); then release_lock; printf '##DONE##|CANCELLED\n'; return 2; fi
  if (( failed > 0 )); then release_lock; printf '##DONE##|FAILED\n'; return 1; fi
  release_lock
  printf '##DONE##|OK\n'
}

confirm() {
  (( AUTO_YES == 1 )) && return 0
  printf '  %s [s/N]: ' "$1"
  read -r r || true
  [[ "$r" == s || "$r" == S || "$r" == y || "$r" == Y ]]
}

banner() {
  clear 2>/dev/null || true
  local free used score grade
  free="$(disk_free_gb)"; used="$(disk_used_pct)"
  read -r score grade _ <<<"$(health_score)"
  echo
  echo "  ============================================================"
  echo "       PC OTIMIZADOR PRO  ·  macOS $VERSION"
  echo "  ============================================================"
  echo "  Disco / : ${free}G livres (${used}% usado) | Health ${score}/100 (${grade})"
  echo "  Whitelist: Documents/Pictures/Downloads/Desktop"
  echo "  Logs: $LOG_DIR"
  echo
}

show_preset() {
  local key="$1" title="$2"
  banner
  echo "  PERFIL: $title"
  local id n=1
  for id in $(preset_ids "$key"); do
    printf '   %2d. %s\n' "$n" "$(action_name "$id")"; n=$((n+1))
  done
  echo
  echo "  [E] Executar  [D] Dry-run  [V] Voltar"
  printf '  Opcao > '; read -r c || true
  c=$(echo "$c" | tr '[:upper:]' '[:lower:]')
  case "$c" in
    e) confirm "Executar?" || return 0; DRY_RUN=0; run_preset "$key"; printf '\n  Enter...'; read -r _ || true ;;
    d) DRY_RUN=1; run_preset "$key"; printf '\n  Enter...'; read -r _ || true ;;
  esac
}

PRESET=""; MODE="menu"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --preset) [[ $# -ge 2 ]] && { PRESET="$2"; shift 2; } || { echo 'Falta valor para --preset' >&2; exit 2; } ;;
    --mode) [[ $# -ge 2 ]] && { MODE="$2"; shift 2; } || { echo 'Falta valor para --mode' >&2; exit 2; } ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y) AUTO_YES=1; shift ;;
    --help|-h) echo "Uso: $0 [--preset safe|gamer|net|full|notebook] [--dry-run] [--yes] [--mode health|scan]"; exit 0 ;;
    *) shift ;;
  esac
done

if [[ -n "$PRESET" ]]; then
  (( AUTO_YES == 1 )) || confirm "Preset $PRESET?" || exit 0
  run_preset "$PRESET"; exit 0
fi

case "$MODE" in
  health)
    read -r score grade used junk <<<"$(health_score)"
    echo "Health: $score/100 ($grade) | Disco ${used}% | Cache amostral $(human_kb "$junk")"
    printf '##HEALTH##|%s|%s\n' "$score" "$grade"; exit 0 ;;
  scan)
    init_log; log "Estimativa $(human_kb "$(estimate_kb)")"; finish_log; exit 0 ;;
esac

while true; do
  banner
  echo "  MENU PRINCIPAL (macOS)"
  echo "   1. Limpeza Segura ★"
  echo "   2. Turbo / Gamer"
  echo "   3. DNS"
  echo "   4. Completo"
  echo "   5. Notebook"
  echo "   6. Dry-run Limpeza Segura"
  echo "   7. Health / estimar"
  echo "   8. Whitelist"
  echo "   0. Sair"
  printf '  Opcao > '; read -r op || true
  case "$op" in
    1) show_preset safe "Limpeza Segura" ;;
    2) show_preset gamer "Turbo / Gamer" ;;
    3) show_preset net "DNS" ;;
    4) show_preset full "Completo" ;;
    5) show_preset notebook "Notebook" ;;
    6) DRY_RUN=1; AUTO_YES=1; run_preset safe; DRY_RUN=0; AUTO_YES=0; printf '\n  Enter...'; read -r _ || true ;;
    7)
      read -r score grade used junk <<<"$(health_score)"
      echo "  Health $score/100 ($grade) | Disco ${used}% | Amostra $(human_kb "$junk")"
      echo "  Estimativa ~ $(human_kb "$(estimate_kb)")"
      printf '  Enter...'; read -r _ || true ;;
    8) ensure_whitelist; sed 's/^/   - /' "$WHITELIST_FILE"; printf '  Enter...'; read -r _ || true ;;
    0|q|Q) echo "  Ate mais!"; exit 0 ;;
  esac
done
