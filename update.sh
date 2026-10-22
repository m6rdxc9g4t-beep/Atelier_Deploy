#!/usr/bin/env bash
# Met à jour les apps (dernier commit de leur branche), reconstruit et relance.
# Usage :  sudo ./update.sh            toutes les apps
#          sudo ./update.sh viz        une seule (nexus, viz, tab, projets, portail)
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"

step "Mise à jour du code"
git_auth pull -q --ff-only 2>/dev/null && ok "kit de déploiement à jour" || warn "kit de déploiement : pas de mise à jour"
sync_apps

case "${1:-all}" in
  all)     services=() ;;
  nexus)   services=(nexus-backend nexus-frontend) ;;
  viz)     services=(viz) ;;
  tab)     services=(caddy nexus-backend) ;;   # Tab est servi par Caddy, et son MCP vit dans Nexus
  projets) services=(projets caddy) ;;        # l'interface de Projets est servie par Caddy
  portail) services=(portail caddy) ;;
  *) die "App inconnue : $1 (nexus, viz, tab, projets, portail)" ;;
esac

step "Reconstruction"
compose build "${services[@]}"
step "Redémarrage"
compose up -d --remove-orphans "${services[@]}"
docker image prune -f >/dev/null
ok "terminé"
compose ps
