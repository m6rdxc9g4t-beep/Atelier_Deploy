#!/usr/bin/env bash
# Met à jour les apps (dernier commit de leur branche), reconstruit et relance.
# Usage :  sudo ./update.sh            toutes les apps
#          sudo ./update.sh viz        une seule (nexus, viz, tab, convert, datamind (+ sa démo publique), projets, wiki, hub, formulaire, tresorerie, savoir, cine, portfolio, ops, mission, ia, portail)
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"
verrou refuser

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

# Services à reconstruire et dépôts dont le code avance, pour la cible demandée.
depots=()
case "${1:-all}" in
  all)     services=() ;;
  nexus)   services=(nexus-backend nexus-frontend); depots=(atelier_nexus) ;;
  viz)     services=(viz); depots=(atelier_viz) ;;
  tab)     services=(caddy nexus-backend); depots=(atelier-tab) ;;   # Tab est servi par Caddy, et son MCP vit dans Nexus
  projets) services=(projets caddy); depots=(atelier_projets) ;;     # l'interface de Projets est servie par Caddy
  portail) services=(portail caddy) ;;
  cine|wiki|formulaire|convert) services=("$1"); depots=("atelier_$1") ;;
  savoir)  services=(savoir); depots=(atelier-savoir) ;;
  tresorerie) services=(tresorerie); depots=(atelier_tr-sorerie) ;;
  dates|suivi) die "$1 ne tourne plus sur le VPS : elle est sur Vercel, qui se met à jour tout seul à chaque commit." ;;
  # DataMind (Agent_Data) : l'image est construite par datamind, puis la démo publique (datamind-demo, même image)
  # est relancée sur la nouvelle version ; Caddy et le portail connaissent leurs adresses et leurs tuiles.
  datamind) services=(datamind datamind-demo caddy portail); depots=(agent_data) ;;
  portfolio) services=(portfolio caddy portail); depots=(atelier_portefolio) ;;  # Caddy et le portail connaissent son adresse et sa tuile
  ops)     services=(ops caddy portail); depots=(agent-ops-lab) ;;    # Sites & tests : Agent Ops Lab (Caddy et le portail connaissent son adresse)
  mission) services=(mission caddy portail); depots=(atelier_mission) ;; # Sites & tests : Atelier Mission (idem)
  hub)     services=(hub caddy portail); depots=(atelier_hub) ;;      # Atelier Hub : Caddy et le portail connaissent son adresse et sa tuile
  ia|ollama) services=(ollama) ;;             # IA du serveur : télécharge le modèle choisi dans .env
  *) die "App inconnue : $1 (nexus, viz, tab, convert, datamind, projets, wiki, hub, formulaire, tresorerie, savoir, cine, portfolio, ops, mission, ia, portail)" ;;
esac

ensure_secrets
ensure_ia
# Une cible ne fait avancer que son propre code : celui des autres apps attend leur reconstruction.
if [ "${1:-all}" = all ]; then sync_apps; else sync_apps --seulement "${depots[@]}"; fi
ensure_dirs

# Données DVF de l'observatoire immobilier (Portfolio) : retéléchargées au plus une fois par mois.
export DVF_CACHE_KEY="${DVF_CACHE_KEY:-$(date +%Y-%m)}"

step "Reconstruction"
verifier_docker
nettoyer
ok "espace libre : $(libre_go) Go"
if [ ${#services[@]} -eq 0 ]; then
  # L'ordre de compose varie : datamind-demo (image construite par datamind) passe en dernier.
  mapfile -t services < <(compose config --services | grep -vx datamind-demo; echo datamind-demo)
fi
deployer_services "${services[@]}" || true
step "Redémarrage"
compose up -d --remove-orphans "${services[@]}"
case "${1:-all}" in all|ia|ollama) pull_model ;; esac
nettoyer
if [ ${#RATES[@]} -gt 0 ]; then
  compose ps
  die "non mis à jour : ${RATES[*]} (voir plus haut ; les autres services demandés sont à jour)"
fi
# Une mise à jour réussie efface l'échec noté par auto-update.sh pour cette app (ou pour toutes).
case "${1:-all}" in all) rm -f "$ROOT"/logs/echec-* ;; *) rm -f "$ROOT/logs/echec-$1" ;; esac
ok "terminé"
compose ps
