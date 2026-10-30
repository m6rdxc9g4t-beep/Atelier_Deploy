#!/usr/bin/env bash
# Met à jour les apps (dernier commit de leur branche), reconstruit et relance.
# Usage :  sudo ./update.sh            toutes les apps
#          sudo ./update.sh viz        une seule (nexus, viz, tab, convert, projets, wiki, formulaire, tresorerie, savoir, cine, dates, suivi, portfolio, ia, portail)
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"

step "Mise à jour du code"
if [ -z "${ATELIER_KIT_A_JOUR:-}" ]; then
  avant=$(git rev-parse HEAD)
  if git_auth pull -q --ff-only; then
    if [ "$(git rev-parse HEAD)" != "$avant" ]; then
      ok "kit de déploiement mis à jour ($(git rev-parse --short HEAD)) : relance avec la nouvelle version"
      # Le script vient peut-être de changer : on repart de la version fraîchement récupérée.
      ATELIER_KIT_A_JOUR=1 exec "$ROOT/update.sh" "$@"
    fi
    ok "kit de déploiement à jour"
  else
    warn "kit de déploiement : récupération impossible, on continue avec la version locale"
  fi
fi
ensure_secrets
ensure_ia
sync_apps
ensure_dirs

case "${1:-all}" in
  all)     services=() ;;
  nexus)   services=(nexus-backend nexus-frontend) ;;
  viz)     services=(viz) ;;
  tab)     services=(caddy nexus-backend) ;;   # Tab est servi par Caddy, et son MCP vit dans Nexus
  projets) services=(projets caddy) ;;        # l'interface de Projets est servie par Caddy
  portail) services=(portail caddy) ;;
  cine|savoir|tresorerie|wiki|formulaire|convert|dates|suivi) services=("$1") ;;
  portfolio) services=(portfolio caddy portail) ;;  # Caddy et le portail connaissent son adresse et sa tuile
  ia|ollama) services=(ollama) ;;             # IA du serveur : télécharge le modèle choisi dans .env
  *) die "App inconnue : $1 (nexus, viz, tab, convert, projets, wiki, formulaire, tresorerie, savoir, cine, dates, suivi, portfolio, ia, portail)" ;;
esac

step "Reconstruction"
compose build "${services[@]}"
step "Redémarrage"
compose up -d --remove-orphans "${services[@]}"
case "${1:-all}" in all|ia|ollama) pull_model ;; esac
docker image prune -f >/dev/null
ok "terminé"
compose ps
