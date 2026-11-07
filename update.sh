#!/usr/bin/env bash
# Met à jour les apps (dernier commit de leur branche), reconstruit et relance.
# Usage :  sudo ./update.sh            toutes les apps
#          sudo ./update.sh viz        une seule (nexus, viz, tab, convert, datamind (+ sa démo publique), projets, wiki, formulaire, tresorerie, savoir, cine, portfolio, ops, mission, ia, portail)
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
  cine|savoir|tresorerie|wiki|formulaire|convert) services=("$1") ;;
  dates|suivi) die "$1 ne tourne plus sur le VPS : elle est sur Vercel, qui se met à jour tout seul à chaque commit." ;;
  # DataMind (Agent_Data) : l'image est construite par datamind, puis la démo publique (datamind-demo, même image)
  # est relancée sur la nouvelle version ; Caddy et le portail connaissent leurs adresses et leurs tuiles.
  datamind) services=(datamind datamind-demo caddy portail) ;;
  portfolio) services=(portfolio caddy portail) ;;  # Caddy et le portail connaissent son adresse et sa tuile
  ops)     services=(ops caddy portail) ;;    # Sites & tests : Agent Ops Lab (Caddy et le portail connaissent son adresse)
  mission) services=(mission caddy portail) ;; # Sites & tests : Atelier Mission (idem)
  ia|ollama) services=(ollama) ;;             # IA du serveur : télécharge le modèle choisi dans .env
  *) die "App inconnue : $1 (nexus, viz, tab, convert, datamind, projets, wiki, formulaire, tresorerie, savoir, cine, portfolio, ops, mission, ia, portail)" ;;
esac

# Le disque du VPS est petit (40 Go) : une reconstruction garde l'ancienne image (en service) à côté de la
# nouvelle, plus le cache de construction. Tout reconstruire d'un coup demande donc plus de 10 Go libres.
# On reconstruit une app à la fois : construire, relancer, supprimer l'ancienne image et le cache, puis la suivante.
libre_go() { df -Pk "$ROOT" | awk 'NR==2 { printf "%d", $4 / 1048576 }'; }
nettoyer() {
  docker image prune -f >/dev/null 2>&1 || true
  docker builder prune -af >/dev/null 2>&1 || warn "nettoyage du cache de construction impossible"
}

# Données DVF de l'observatoire immobilier (Portfolio) : retéléchargées au plus une fois par mois.
export DVF_CACHE_KEY="${DVF_CACHE_KEY:-$(date +%Y-%m)}"

step "Reconstruction"
nettoyer
ok "espace libre : $(libre_go) Go"
if [ ${#services[@]} -eq 0 ]; then
  # L'ordre de compose varie : datamind-demo (image construite par datamind) passe en dernier.
  mapfile -t services < <(compose config --services | grep -vx datamind-demo; echo datamind-demo)
fi
for service in "${services[@]}"; do
  [ "$(libre_go)" -ge 3 ] || die "moins de 3 Go libres sur le disque : libère de la place (df -h /, sudo docker system df) puis relance"
  compose build "$service"
  compose up -d "$service"
  nettoyer
  ok "$service à jour (espace libre : $(libre_go) Go)"
done
step "Redémarrage"
compose up -d --remove-orphans "${services[@]}"
case "${1:-all}" in all|ia|ollama) pull_model ;; esac
nettoyer
ok "terminé"
compose ps
