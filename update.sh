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
# lies : nombre de services, en tête de liste, construits depuis le code de l'app. Ils passent ensemble à la nouvelle
# version ou reviennent ensemble à la précédente (deployer_services --lies) ; Caddy et le portail qui les suivent
# n'accompagnent la cible que pour le kit.
depots=(); lies=0
case "${1:-all}" in
  all)     services=() ;;
  nexus)   services=(nexus-backend nexus-frontend); depots=(atelier_nexus); lies=2 ;;
  viz)     services=(viz); depots=(atelier_viz); lies=1 ;;
  tab)     services=(caddy nexus-backend); depots=(atelier-tab); lies=2 ;;   # Tab est servi par Caddy, et son MCP vit dans Nexus
  projets) services=(projets caddy); depots=(atelier_projets); lies=2 ;;     # l'interface de Projets est servie par Caddy
  portail) services=(portail caddy) ;;
  cine|wiki|formulaire|convert) services=("$1"); depots=("atelier_$1"); lies=1 ;;
  savoir)  services=(savoir); depots=(atelier-savoir); lies=1 ;;
  tresorerie) services=(tresorerie); depots=(atelier_tr-sorerie); lies=1 ;;
  dates|suivi) die "$1 ne tourne plus sur le VPS : elle est sur Vercel, qui se met à jour tout seul à chaque commit." ;;
  # DataMind (Agent_Data) : l'image est construite par datamind, puis la démo publique (datamind-demo, même image)
  # est relancée sur la nouvelle version ; Caddy et le portail connaissent leurs adresses et leurs tuiles.
  datamind) services=(datamind datamind-demo caddy portail); depots=(agent_data); lies=2 ;;
  portfolio) services=(portfolio caddy portail); depots=(atelier_portefolio); lies=1 ;;  # Caddy et le portail connaissent son adresse et sa tuile
  ops)     services=(ops caddy portail); depots=(agent-ops-lab); lies=1 ;;    # Sites & tests : Agent Ops Lab (Caddy et le portail connaissent son adresse)
  mission) services=(mission caddy portail); depots=(atelier_mission); lies=1 ;; # Sites & tests : Atelier Mission (idem)
  hub)     services=(hub caddy portail); depots=(atelier_hub); lies=1 ;;      # Atelier Hub : Caddy et le portail connaissent son adresse et sa tuile
  ia|ollama) services=(ollama) ;;             # IA du serveur : télécharge le modèle choisi dans .env
  *) die "App inconnue : $1 (nexus, viz, tab, convert, datamind, projets, wiki, hub, formulaire, tresorerie, savoir, cine, portfolio, ops, mission, ia, portail)" ;;
esac

ensure_secrets
ensure_ia

# Caddy et le portail accompagnent ces cibles pour le jour où le kit leur apprend une adresse ou une tuile.
# Si rien de ce qui les concerne n'a changé depuis leur dernier déploiement, on n'y touche pas.
case "${1:-all}" in
  datamind|portfolio|ops|mission|hub)
    utiles=()
    for service in "${services[@]}"; do
      case "$service" in caddy|portail) if kit_a_jour "$service"; then continue; fi ;; esac
      utiles+=("$service")
    done
    services=("${utiles[@]}") ;;
esac

# Commit en service de l'app visée : son code y revient si elle ne passe pas à la nouvelle version.
declare -A en_service=()
for depot in "${depots[@]}"; do
  en_service[$depot]=""
  # Seulement pour un dépôt déjà cloné : sans son .git, la commande répondrait pour le dépôt du kit lui-même.
  [ ! -d "apps/$depot/.git" ] || en_service[$depot]="$(git -C "apps/$depot" rev-parse -q --verify HEAD 2>/dev/null || true)"
done

# Une cible ne fait avancer que son propre code : celui des autres apps attend leur reconstruction.
if [ "${1:-all}" = all ]; then sync_apps; else sync_apps --seulement "${depots[@]}"; fi
ensure_dirs

step "Reconstruction"
verifier_docker
nettoyer
ok "espace libre : $(libre_go) Go"
if [ ${#services[@]} -eq 0 ]; then mapfile -t services < <(tous_les_services); fi
deployer_services --lies "$lies" "${services[@]}" || true
if [ "$LOT_ANNULE" -eq 1 ]; then
  # L'app reste sur sa version précédente : son code y revient aussi. Sinon la prochaine reconstruction de Caddy (pour
  # une autre app) servirait la nouvelle interface de Projets ou de Tab devant l'ancienne API, et auto-update.sh
  # croirait l'app à jour.
  for depot in "${depots[@]}"; do
    [ -n "${en_service[$depot]}" ] || continue
    if git -C "apps/$depot" reset -q --hard "${en_service[$depot]}" 2>/dev/null; then
      warn "$depot : code remis sur la version en service (${en_service[$depot]:0:7})"
    else
      warn "$depot : code impossible à remettre sur la version en service (${en_service[$depot]:0:7})"
    fi
  done
fi
step "Redémarrage"
relancer_tout "${services[@]}"
case "${1:-all}" in all|ia|ollama) pull_model ;; esac
if [ ${#RATES[@]} -gt 0 ]; then
  compose ps
  if [ "$LOT_ANNULE" -eq 1 ]; then
    die "non mis à jour : ${RATES[*]} (voir plus haut ; l'app reste sur sa version précédente)"
  fi
  die "non mis à jour : ${RATES[*]} (voir plus haut ; les autres services demandés sont à jour)"
fi
# Une mise à jour réussie efface l'échec noté par auto-update.sh pour cette app (ou pour toutes).
case "${1:-all}" in all) rm -f "$ROOT"/logs/echec-* ;; *) rm -f "$ROOT/logs/echec-$1" ;; esac
ok "terminé"
compose ps
