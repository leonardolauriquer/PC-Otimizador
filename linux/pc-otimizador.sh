#!/usr/bin/env bash
# PC Otimizador Pro — Linux engine + CLI
# Seguro por padrao: nao apaga Documentos/Fotos/Downloads/Desktop.
set -u
# nao use set -e: limpeza continua mesmo se um passo falhar

VERSION="5.10-linux"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
AUTO_YES=0
LANG_UI="${LANG_UI:-pt}"
CANCEL_FILE="${TMPDIR:-/tmp}/pc-otimizador-cancel.flag"
LOG_DIR="${HOME}/.local/share/pc-otimizador/logs"
WHITELIST_FILE="${LOG_DIR}/whitelist.txt"
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

# ── i18n minimo ──────────────────────────────────────────────────────────────
t() {
  case "$1" in
    done) [[ "$LANG_UI" == en ]] && echo "Done" || echo "Concluido" ;;
    dry) [[ "$LANG_UI" == en ]] && echo "Dry-run" || echo "Simulacao" ;;
    cancel) [[ "$LANG_UI" == en ]] && echo "Cancelled" || echo "Cancelado" ;;
    *) echo "$1" ;;
  esac
}

log() {
  local level="${2:-INFO}"
  local line="[$(date +%H:%M:%S)] [$level] $1"
  printf '%s\n' "$line"
  [[ -n "$SESSION_LOG" ]] && printf '%s\n' "$line" >>"$SESSION_LOG"
  # stream for possible GUI wrappers
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
    echo "PC Otimizador Pro Linux $VERSION"
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

cancel_requested() {
  [[ -f "$CANCEL_FILE" ]] && return 0
  return 1
}

reset_cancel() { rm -f "$CANCEL_FILE" 2>/dev/null || true; }

# ── whitelist ────────────────────────────────────────────────────────────────
ensure_whitelist() {
  if [[ ! -f "$WHITELIST_FILE" ]]; then
    cat >"$WHITELIST_FILE" <<EOF
$HOME/Documents
$HOME/Documentos
$HOME/Pictures
$HOME/Imagens
$HOME/Fotos
$HOME/Videos
$HOME/Vídeos
$HOME/Desktop
$HOME/Área de Trabalho
$HOME/Downloads
EOF
  fi
}

is_protected() {
  local path="$1"
  ensure_whitelist
  local w
  # normalize trailing slash; require path boundary (not prefix collision)
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

# ── helpers ──────────────────────────────────────────────────────────────────
bytes_of() {
  local p="$1"
  if [[ -d "$p" ]]; then
    du -sb "$p" 2>/dev/null | awk '{print $1}'
  elif [[ -f "$p" ]]; then
    stat -c%s "$p" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

kb_of_path() {
  local b
  b="$(bytes_of "$1")"
  echo $(( b / 1024 ))
}

human_kb() {
  local kb="$1"
  if (( kb > 1048576 )); then awk -v k="$kb" 'BEGIN{printf "%.2f GB", k/1048576}'
  elif (( kb > 1024 )); then awk -v k="$kb" 'BEGIN{printf "%.1f MB", k/1024}'
  else echo "${kb} KB"
  fi
}

safe_rm_tree() {
  local p="$1"
  [[ -e "$p" ]] || return 0
  [[ -L "$p" ]] && { log "Ignorado (symlink): $p" WARN; return 0; }
  case "$p" in
    /tmp/*|/var/tmp/*|"$HOME"/.cache/*|"$HOME"/.local/share/Trash/*|"$HOME"/.thumbnails/*|"$HOME"/.var/app/*/cache) ;;
    *) log "Alvo recusado pela allowlist: $p" WARN; return 0 ;;
  esac
  if is_protected "$p"; then
    log "Whitelist: protegido $p" WARN
    return 0
  fi
  local kb
  kb="$(kb_of_path "$p")"
  if (( DRY_RUN == 1 )); then
    log "[DRY-RUN] Removeria $p (~$(human_kb "$kb"))"
    FREED_KB=$((FREED_KB + kb))
    return 0
  fi
  # limpa conteudo, mantem pasta quando e cache padrao
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
  for base in /tmp /var/tmp; do
    [[ -d "$base" ]] || continue
    while IFS= read -r -d '' item; do
      safe_rm_tree "$item"
    done < <(find "$base" -mindepth 1 -maxdepth 1 -user "$uid" -mtime +1 -print0 2>/dev/null)
  done
}

owned_tmp_kb() {
  local base item total=0 uid
  uid="$(id -u)"
  for base in /tmp /var/tmp; do
    [[ -d "$base" ]] || continue
    while IFS= read -r -d '' item; do
      total=$(( total + $(kb_of_path "$item") ))
    done < <(find "$base" -mindepth 1 -maxdepth 1 -user "$uid" -mtime +1 -print0 2>/dev/null)
  done
  echo "$total"
}

need_sudo() {
  if [[ "${EUID}" -eq 0 ]]; then return 0; fi
  if command -v sudo >/dev/null 2>&1; then
    sudo -n true 2>/dev/null && return 0
  fi
  return 1
}

run_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif (( DRY_RUN == 1 )); then
    log "[DRY-RUN] sudo $*"
    return 0
  else
    sudo "$@"
  fi
}

# ── system info / health ─────────────────────────────────────────────────────
disk_free_gb() {
  df -BG / 2>/dev/null | awk 'NR==2{gsub(/G/,"",$4); print $4}'
}
disk_used_pct() {
  df -P / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}'
}
mem_used_pct() {
  free | awk '/Mem:/{printf "%d", ($3/$2)*100}'
}

health_score() {
  local score=100 used mem junk
  used="$(disk_used_pct)"; used=${used:-50}
  mem="$(mem_used_pct)"; mem=${mem:-50}
  junk=0
  junk=$((junk + $(kb_of_path "$HOME/.cache")))
   junk=$((junk + $(owned_tmp_kb)))
  (( used >= 95 )) && score=$((score - 40))
  (( used >= 85 && used < 95 )) && score=$((score - 25))
  (( used >= 75 && used < 85 )) && score=$((score - 15))
  (( mem >= 90 )) && score=$((score - 20))
  (( mem >= 80 && mem < 90 )) && score=$((score - 10))
  (( junk > 5000000 )) && score=$((score - 20))
  (( junk > 2000000 && junk <= 5000000 )) && score=$((score - 12))
  (( junk > 500000 && junk <= 2000000 )) && score=$((score - 6))
  (( score < 0 )) && score=0
  (( score > 100 )) && score=100
  local grade=A
  (( score < 85 )) && grade=B
  (( score < 70 )) && grade=C
  (( score < 50 )) && grade=D
  (( score < 30 )) && grade=E
  echo "$score $grade $used $mem $junk"
}

detect_pkg() {
  command -v apt-get >/dev/null && { echo apt; return; }
  command -v dnf >/dev/null && { echo dnf; return; }
  command -v pacman >/dev/null && { echo pacman; return; }
  command -v zypper >/dev/null && { echo zypper; return; }
  echo none
}

# ── actions ──────────────────────────────────────────────────────────────────
act_temp() {
  clean_owned_tmp
  # user temp caches (nao home inteiro)
  safe_rm_tree "$HOME/.cache/thumbnails"
  safe_rm_tree "$HOME/.thumbnails"
}

act_user_cache_safe() {
  # limpa so subpastas tipicas regeneraveis
  local d
  for d in \
    "$HOME/.cache/mesa_shader_cache" \
    "$HOME/.cache/nvidia" \
    "$HOME/.cache/fontconfig" \
    "$HOME/.cache/mozilla/firefox" \
    "$HOME/.cache/google-chrome" \
    "$HOME/.cache/chromium" \
    "$HOME/.cache/BraveSoftware" \
    "$HOME/.var/app"/*/cache
  do
    [[ -e $d ]] || continue
    # firefox/chrome: so Cache se existir estrutura
    if [[ -d "$d" ]]; then
      if [[ "$d" == *firefox* ]]; then
        find "$d" -type d -name 'cache2' 2>/dev/null | while read -r c; do safe_rm_tree "$c"; done
      else
        safe_rm_tree "$d"
      fi
    fi
  done
}

act_trash() {
  safe_rm_tree "$HOME/.local/share/Trash/files"
  safe_rm_tree "$HOME/.local/share/Trash/info"
}

act_journal() {
  if (( DRY_RUN == 1 )); then
    log "[DRY-RUN] journalctl --vacuum-time=7d"
    return 0
  fi
  if command -v journalctl >/dev/null; then
    run_bounded 300 run_root journalctl --vacuum-time=7d 2>/dev/null || { log "journal vacuum falhou ou excedeu 300s" ERROR; return 1; }
  else
    log "journalctl indisponivel" WARN; return 20
  fi
}

act_pkg_cache() {
  local pm
  pm="$(detect_pkg)"
  case "$pm" in
    apt)
      if (( DRY_RUN == 1 )); then log "[DRY-RUN] apt-get clean && autoremove"; return 0; fi
      run_bounded 300 run_root apt-get clean -y 2>/dev/null || { log "apt-get clean falhou ou excedeu 300s" ERROR; return 1; }
      ;;
    dnf)
      if (( DRY_RUN == 1 )); then log "[DRY-RUN] dnf clean all"; return 0; fi
      run_bounded 300 run_root dnf clean all -y 2>/dev/null || { log "dnf clean falhou ou excedeu 300s" ERROR; return 1; }
      ;;
    pacman)
      if (( DRY_RUN == 1 )); then log "[DRY-RUN] pacman -Sc"; return 0; fi
      run_bounded 300 run_root pacman -Sc --noconfirm 2>/dev/null || { log "pacman clean falhou ou excedeu 300s" ERROR; return 1; }
      ;;
    zypper)
      if (( DRY_RUN == 1 )); then log "[DRY-RUN] zypper clean"; return 0; fi
      run_bounded 300 run_root zypper clean 2>/dev/null || { log "zypper clean falhou ou excedeu 300s" ERROR; return 1; }
      ;;
    *) log "Gerenciador de pacotes nao detectado" WARN; return 20 ;;
  esac
}

act_dns() {
  if (( DRY_RUN == 1 )); then log "[DRY-RUN] flush DNS (resolvectl/nscd)"; return 0; fi
  local attempted=0
  if command -v resolvectl >/dev/null; then
    attempted=1
    run_root resolvectl flush-caches 2>/dev/null || { log "resolvectl falhou" ERROR; return 1; }
  elif command -v systemd-resolve >/dev/null; then
    attempted=1
    run_root systemd-resolve --flush-caches 2>/dev/null || { log "systemd-resolve falhou" ERROR; return 1; }
  fi
  if command -v nscd >/dev/null; then
    attempted=1
    run_root nscd -i hosts 2>/dev/null || { log "nscd falhou" ERROR; return 1; }
  fi
  if (( attempted == 0 )); then log "Nenhum resolvedor com flush detectado" WARN; return 20; fi
  log "DNS cache flush confirmado"
}

act_flatpak() {
  if ! command -v flatpak >/dev/null; then log "Flatpak nao instalado"; return 20; fi
  if (( DRY_RUN == 1 )); then log "[DRY-RUN] flatpak uninstall --unused"; return 0; fi
  flatpak uninstall --unused -y 2>/dev/null || { log "flatpak cleanup falhou" ERROR; return 1; }
}

act_snap() {
  if ! command -v snap >/dev/null; then return 20; fi
  if (( DRY_RUN == 1 )); then log "[DRY-RUN] limpar snaps disabled"; return 0; fi
  # remove revisoes antigas disabled
  snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' | while read -r name rev; do
    run_root snap remove "$name" --revision="$rev" 2>/dev/null || true
  done
}

act_trim() {
  if (( DRY_RUN == 1 )); then log "[DRY-RUN] fstrim -av"; return 0; fi
  if command -v fstrim >/dev/null; then
    run_bounded 600 run_root fstrim -av 2>/dev/null || { log "fstrim falhou ou excedeu 600s" ERROR; return 1; }
  else return 20; fi
}

estimate_safe_kb() {
  local total=0
  local p
  for p in "$HOME/.cache/thumbnails" "$HOME/.thumbnails" \
           "$HOME/.local/share/Trash/files" "$HOME/.cache/mesa_shader_cache"; do
    total=$((total + $(kb_of_path "$p")))
  done
  total=$((total + $(owned_tmp_kb)))
  echo "$total"
}

# ── presets (core/presets.json via python3, fallback local) ───────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_JSON="${SCRIPT_DIR}/../core/presets.json"
LOAD_PRESET="${SCRIPT_DIR}/../core/load_preset.py"

preset_ids() {
  local name="${1:-safe}"
  if command -v python3 >/dev/null 2>&1 && [[ -f "$LOAD_PRESET" ]]; then
    local out
    out="$(python3 "$LOAD_PRESET" linux "$name" 2>/dev/null || true)"
    if [[ -n "$out" ]]; then echo "$out"; return 0; fi
  fi
  case "$name" in
    gamer) echo "temp trash cache journal pkg dns flatpak trim" ;;
    net) echo "dns" ;;
    full) echo "temp trash cache journal pkg dns flatpak snap trim" ;;
    notebook) echo "temp trash cache journal pkg dns flatpak" ;;
    *) echo "temp trash cache journal pkg dns" ;;
  esac
}

run_action() {
  case "$1" in
    temp) act_temp ;;
    trash) act_trash ;;
    cache) act_user_cache_safe ;;
    journal) act_journal ;;
    pkg) act_pkg_cache ;;
    dns) act_dns ;;
    flatpak) act_flatpak ;;
    snap) act_snap ;;
    trim) act_trim ;;
    *) log "Acao desconhecida: $1" WARN ;;
  esac
}

action_name() {
  case "$1" in
    temp) echo "Temporarios (/tmp)" ;;
    trash) echo "Lixeira" ;;
    cache) echo "Caches regeneraveis do usuario" ;;
    journal) echo "Journald (7 dias)" ;;
    pkg) echo "Cache de pacotes (apt/dnf/pacman)" ;;
    dns) echo "Flush DNS" ;;
    flatpak) echo "Flatpak unused" ;;
    snap) echo "Snaps antigos" ;;
    trim) echo "fstrim (SSD)" ;;
    *) echo "$1" ;;
  esac
}

run_preset() {
  local name="$1"
  local ids=( $(preset_ids "$name") )
  local total=${#ids[@]}
  local i=0 id
  FREED_KB=0
  acquire_lock || { printf '##DONE##|BLOCKED|CONCURRENT\n'; return 3; }
  trap release_lock EXIT INT TERM
  reset_cancel
  init_log
  ensure_whitelist

  local free_before used_before
  free_before="$(disk_free_gb)"
  used_before="$(disk_used_pct)"
  printf '##RESULT##|BEFORE|%s|%s\n' "$free_before" "$used_before"

  local est
  est="$(estimate_safe_kb)"
  log "Estimativa aproximada (amostra): $(human_kb "$est")"

  local cancelled=0 failed=0 succeeded=0 skipped=0 rc=0
  for id in "${ids[@]}"; do
    if cancel_requested; then log "$(t cancel)" WARN; cancelled=1; break; fi
    i=$((i + 1))
    progress "$i" "$total" "$(action_name "$id")"
    run_action "$id"; rc=$?
    if (( rc == 0 )); then succeeded=$((succeeded + 1)); printf '##ACTION##|%s|SUCCESS|1|verified\n' "$id"
    elif (( rc == 20 )); then skipped=$((skipped + 1)); printf '##ACTION##|%s|SKIPPED|0|capability unavailable\n' "$id"
    else failed=$((failed + 1)); printf '##ACTION##|%s|FAILED|1|see log\n' "$id"; fi
  done

  local free_after score grade
  free_after="$(disk_free_gb)"
  read -r score grade _ <<<"$(health_score)"
  local summary="Liberado~$(human_kb "$FREED_KB") | Disco livres: ${free_before}G -> ${free_after}G | Health ${score}/100 (${grade})"
  log "$summary"
  finish_log "$summary"
  printf '##RESULT##|AFTER|%s|%s|%s|%s|%s\n' "$free_after" "$FREED_KB" "$score" "$grade" "${SESSION_LOG}"
  printf '##SUMMARY##|SUCCESS=%s|SKIPPED=%s|FAILED=%s|TOTAL=%s\n' "$succeeded" "$skipped" "$failed" "$total"
  if (( cancelled == 1 )); then release_lock; printf '##DONE##|CANCELLED\n'; return 2; fi
  if (( failed > 0 )); then release_lock; printf '##DONE##|FAILED\n'; return 1; fi
  release_lock
  printf '##DONE##|OK\n'
}

confirm() {
  (( AUTO_YES == 1 )) && return 0
  local msg="$1"
  printf '  %s [s/N]: ' "$msg"
  read -r r || true
  [[ "$r" == s || "$r" == S || "$r" == y || "$r" == Y ]]
}

banner() {
  clear 2>/dev/null || true
  local free used score grade mem junk
  free="$(disk_free_gb)"; used="$(disk_used_pct)"
  read -r score grade _ mem junk <<<"$(health_score)"
  echo
  echo "  ============================================================"
  echo "       PC OTIMIZADOR PRO  ·  Linux $VERSION"
  echo "  ============================================================"
  echo "  Host: $(hostname)  |  Disco / : ${free}G livres (${used}% usado)"
  echo "  Health: ${score}/100 (${grade})  |  RAM ~${mem}%  |  PM: $(detect_pkg)"
  echo "  Nao apaga Documentos/Fotos/Downloads (whitelist)."
  echo "  Logs: $LOG_DIR"
  echo
}

show_preset() {
  local key="$1" title="$2"
  banner
  echo "  PERFIL: $title"
  echo "  ----------------------------------------------------------"
  local id n=1
  for id in $(preset_ids "$key"); do
    printf '   %2d. %s\n' "$n" "$(action_name "$id")"
    n=$((n + 1))
  done
  echo
  echo "  [E] Executar  [D] Dry-run  [V] Voltar"
  printf '  Opcao > '
  read -r c || true
  c=$(echo "$c" | tr '[:upper:]' '[:lower:]')
  case "$c" in
    e)
      confirm "Executar limpeza real?" || return 0
      DRY_RUN=0
      run_preset "$key"
      printf '\n  Enter...'; read -r _ || true
      ;;
    d)
      DRY_RUN=1
      run_preset "$key"
      printf '\n  Enter...'; read -r _ || true
      ;;
  esac
}

# ── CLI args ─────────────────────────────────────────────────────────────────
PRESET=""
MODE="menu"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --preset) [[ $# -ge 2 ]] && { PRESET="$2"; shift 2; } || { echo 'Falta valor para --preset' >&2; exit 2; } ;;
    --mode) [[ $# -ge 2 ]] && { MODE="$2"; shift 2; } || { echo 'Falta valor para --mode' >&2; exit 2; } ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y) AUTO_YES=1; shift ;;
    --en) LANG_UI=en; shift ;;
    --help|-h)
      echo "Uso: $0 [--preset safe|gamer|net|full|notebook] [--dry-run] [--yes] [--mode health|scan|menu]"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ -n "$PRESET" ]]; then
  (( AUTO_YES == 1 )) || confirm "Rodar preset $PRESET?" || exit 0
  run_preset "$PRESET"
  exit 0
fi

case "$MODE" in
  health)
    read -r score grade used mem junk <<<"$(health_score)"
    echo "Health Score: $score/100 ($grade)"
    echo "Disco usado: ${used}% | RAM: ${mem}% | Cache amostral: $(human_kb "$junk")"
    printf '##HEALTH##|%s|%s\n' "$score" "$grade"
    exit 0
    ;;
  scan)
    init_log
    est="$(estimate_safe_kb)"
    log "Estimativa amostra: $(human_kb "$est")"
    read -r score grade used mem junk <<<"$(health_score)"
    log "Health: $score/100 ($grade) | Disco ${used}% | RAM ${mem}%"
    finish_log
    exit 0
    ;;
esac

# ── menu ─────────────────────────────────────────────────────────────────────
while true; do
  banner
  echo "  MENU PRINCIPAL (Linux)"
  echo "  ----------------------------------------------------------"
  echo "   1. Limpeza Segura ★"
  echo "   2. Turbo / Gamer (cache GPU + trim)"
  echo "   3. Reparar DNS"
  echo "   4. Preset Completo"
  echo "   5. Notebook"
  echo "   6. Dry-run Limpeza Segura"
  echo "   7. Health Score / estimar"
  echo "   8. Ver whitelist"
  echo "   0. Sair"
  echo
  printf '  Opcao > '
  read -r op || true
  case "$op" in
    1) show_preset safe "Limpeza Segura" ;;
    2) show_preset gamer "Turbo / Gamer" ;;
    3) show_preset net "Reparar DNS" ;;
    4) show_preset full "Completo" ;;
    5) show_preset notebook "Notebook" ;;
    6) DRY_RUN=1; AUTO_YES=1; run_preset safe; DRY_RUN=0; AUTO_YES=0; printf '\n  Enter...'; read -r _ || true ;;
    7)
      read -r score grade used mem junk <<<"$(health_score)"
      echo "  Health: $score/100 ($grade)"
      echo "  Disco ${used}% | RAM ${mem}% | Amostra cache $(human_kb "$junk")"
      echo "  Estimativa limpeza segura ~ $(human_kb "$(estimate_safe_kb)")"
      printf '  Enter...'; read -r _ || true
      ;;
    8)
      ensure_whitelist
      echo "  Whitelist:"
      sed 's/^/   - /' "$WHITELIST_FILE"
      echo "  Arquivo: $WHITELIST_FILE"
      printf '  Enter...'; read -r _ || true
      ;;
    0|q|Q) echo "  Ate mais!"; exit 0 ;;
  esac
done
