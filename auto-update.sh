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
# Journal : logs/auto-update.log (au-delà de 5 Mo, l'ancien contenu passe dans logs/auto-update.log.1)
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"

CRON_FILE=/etc/cron.d/atelier-auto-update
# Verrou de la ligne de cron (un seul passage à la fois) ; le verrou commun de scripts/lib.sh s'y ajoute et
# empêche de croiser une mise à jour manuelle ou une sauvegarde.
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

# Essais accordés à un même commit avant d'attendre le suivant.
ESSAIS_MAX=3

check() {
  local app remote local_sha echec essais
  for app in $(tracked_apps); do
    if ! app_entry "$app" >/dev/null; then warn "$app : app inconnue (AUTO_UPDATE_APPS)"; continue; fi
    read -r remote local_sha <<<"$(shas "$app")"
    if [ "$remote" = "?" ]; then warn "$app : GitHub injoignable, on réessaiera"; continue; fi
    # Échec noté pour ce commit : « commit essais » dans logs/echec-<app> (le code, lui, a déjà avancé).
    echec=""; essais=0
    [ ! -f "$ROOT/logs/echec-$app" ] || read -r echec essais <"$ROOT/logs/echec-$app" || true
    if [ "$echec" = "$remote" ]; then
      # Un échec peut être passager (registre npm injoignable, disque plein) : le même commit est retenté aux passages
      # suivants, puis laissé de côté jusqu'au commit suivant (ou jusqu'à un sudo ./update.sh <app>).
      [[ "$essais" =~ ^[0-9]+$ ]] || essais=1
      [ "$essais" -lt "$ESSAIS_MAX" ] || continue
    else
      essais=0
      [ "$remote" = "$local_sha" ] && continue
    fi
    printf '%s  %s : %s → %s, mise à jour (essai %s/%s)\n' "$(date '+%F %T')" "$app" "${local_sha:0:7}" "${remote:0:7}" "$((essais + 1))" "$ESSAIS_MAX"
    if ./update.sh "$app"; then
      printf '%s  %s : à jour (%s)\n' "$(date '+%F %T')" "$app" "${remote:0:7}"
      rm -f "$ROOT/logs/echec-$app"
    else
      essais=$((essais + 1))
      mkdir -p "$ROOT/logs"; echo "$remote $essais" >"$ROOT/logs/echec-$app"
      if [ "$essais" -lt "$ESSAIS_MAX" ]; then
        printf '%s  %s : ÉCHEC de la mise à jour (voir ci-dessus), essai %s/%s ; nouvel essai au prochain passage\n' "$(date '+%F %T')" "$app" "$essais" "$ESSAIS_MAX"
      else
        printf '%s  %s : ÉCHEC de la mise à jour (voir ci-dessus), essai %s/%s ; ce commit ne sera plus retenté (sudo ./update.sh %s pour réessayer)\n' "$(date '+%F %T')" "$app" "$essais" "$ESSAIS_MAX" "$app"
      fi
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
      echec=""; [ ! -f "$ROOT/logs/echec-$app" ] || read -r echec _ <"$ROOT/logs/echec-$app" || true
      if [ -n "$echec" ] && [ "$echec" = "$remote" ]; then
        warn "$app : ÉCHEC de la mise à jour vers ${remote:0:7} (journal ci-dessous ; nouvel essai : sudo ./update.sh $app)"
      elif [ "$remote" = "$local_sha" ]; then ok "$app : à jour (${local_sha:0:7})"
      else warn "$app : installé ${local_sha:0:7}, publié ${remote:0:7}"; fi
    done
    if [ -f "$LOG" ]; then echo; tail -n 8 "$LOG"; fi
    ;;
  check)
    verrou silencieux
    # Le journal reçoit toute la sortie des constructions : il est borné (5 Mo, un ancien gardé dans auto-update.log.1).
    tourner_journal "$LOG"
    check ;;
  *) die "Usage : sudo ./auto-update.sh [install|remove|status]" ;;
esac
