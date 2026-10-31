#!/usr/bin/env bash
# Mise à jour automatique : le VPS suit GitHub, comme Vercel.
# Toutes les 5 minutes (cron), compare le dernier commit de la branche de chaque app suivie
# avec la version installée ; s'il a changé, lance  ./update.sh <app>  (reconstruction + redémarrage).
#
#   sudo ./auto-update.sh install   active la vérification toutes les 5 minutes
#   sudo ./auto-update.sh remove    la désactive
#   sudo ./auto-update.sh status    apps suivies, versions installée et publiée, dernières lignes du journal
#   sudo ./auto-update.sh           une vérification maintenant (ce que lance le cron)
#
# Apps suivies : AUTO_UPDATE_APPS dans .env (noms de update.sh, séparés par des espaces), aucune par défaut.
# Journal : logs/auto-update.log
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"

CRON_FILE=/etc/cron.d/atelier-auto-update
LOCK=/run/atelier-auto-update.lock
LOG="$ROOT/logs/auto-update.log"

# dates et suivi ne tournent plus sur le VPS (Vercel uniquement) : ignorées même si .env les cite encore
tracked_apps() { local a; a="$(env_get AUTO_UPDATE_APPS)"; echo " $a " | sed -e 's/ dates / /g' -e 's/ suivi / /g' | xargs; }

# app (nom de update.sh) → « dossier|dépôt|variable de branche » de scripts/lib.sh
app_entry() {
  local want="BRANCH_${1^^}" entry dir repo var
  for entry in "${APPS[@]}"; do
    IFS='|' read -r dir repo var <<<"$entry"
    [ "$var" = "$want" ] && { echo "$entry"; return 0; }
  done
  return 1
}

# Commit publié sur GitHub et commit installé, pour une app
shas() {
  local entry dir repo var branch owner remote local_sha
  entry="$(app_entry "$1")" || { echo "? ?"; return; }
  IFS='|' read -r dir repo var <<<"$entry"
  branch="$(env_get "$var")"; branch="${branch:-main}"
  owner="$(env_get GITHUB_OWNER)"; owner="${owner:-m6rdxc9g4t-beep}"
  remote="$(git_auth ls-remote "https://github.com/$owner/$repo.git" "refs/heads/$branch" 2>/dev/null | cut -f1)"
  local_sha="$(git -C "apps/$dir" rev-parse HEAD 2>/dev/null || true)"
  echo "${remote:-?} ${local_sha:-?}"
}

check() {
  local app remote local_sha
  for app in $(tracked_apps); do
    if ! app_entry "$app" >/dev/null; then warn "$app : app inconnue (AUTO_UPDATE_APPS)"; continue; fi
    read -r remote local_sha <<<"$(shas "$app")"
    if [ "$remote" = "?" ]; then warn "$app : GitHub injoignable, on réessaiera"; continue; fi
    [ "$remote" = "$local_sha" ] && continue
    # Une version qui a déjà échoué n'est pas retentée toutes les 5 minutes : on attend le commit suivant.
    if [ "$(cat "$ROOT/logs/echec-$app" 2>/dev/null)" = "$remote" ]; then continue; fi
    printf '%s  %s : %s → %s, mise à jour\n' "$(date '+%F %T')" "$app" "${local_sha:0:7}" "${remote:0:7}"
    if ./update.sh "$app"; then
      printf '%s  %s : à jour (%s)\n' "$(date '+%F %T')" "$app" "${remote:0:7}"
      rm -f "$ROOT/logs/echec-$app"
    else
      printf '%s  %s : ÉCHEC de la mise à jour (voir ci-dessus) ; ce commit ne sera pas retenté\n' "$(date '+%F %T')" "$app"
      mkdir -p "$ROOT/logs"; echo "$remote" >"$ROOT/logs/echec-$app"
    fi
  done
  return 0
}

case "${1:-check}" in
  install)
    [ "$(id -u)" -eq 0 ] || die "Lance-le avec sudo : sudo ./auto-update.sh install"
    mkdir -p "$ROOT/logs"
    cat >"$CRON_FILE" <<CRON
# Atelier : le VPS suit GitHub (voir $ROOT/auto-update.sh)
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/5 * * * * root cd "$ROOT" && flock -n $LOCK ./auto-update.sh >>"$LOG" 2>&1
CRON
    chmod 644 "$CRON_FILE"
    ok "vérification automatique toutes les 5 minutes ($CRON_FILE)"
    ok "apps suivies : $(tracked_apps | sed 's/^$/aucune/')  (AUTO_UPDATE_APPS dans .env)"
    ok "journal : $LOG"
    ;;
  remove)
    [ "$(id -u)" -eq 0 ] || die "Lance-le avec sudo : sudo ./auto-update.sh remove"
    rm -f "$CRON_FILE"; ok "mise à jour automatique désactivée"
    ;;
  status)
    if [ -f "$CRON_FILE" ]; then ok "active (toutes les 5 minutes)"; else warn "inactive (sudo ./auto-update.sh install)"; fi
    for app in $(tracked_apps); do
      read -r remote local_sha <<<"$(shas "$app")"
      if [ "$remote" = "$local_sha" ]; then ok "$app : à jour (${local_sha:0:7})"
      else warn "$app : installé ${local_sha:0:7}, publié ${remote:0:7}"; fi
    done
    if [ -f "$LOG" ]; then echo; tail -n 8 "$LOG"; fi
    ;;
  check) check ;;
  *) die "Usage : sudo ./auto-update.sh [install|remove|status]" ;;
esac
