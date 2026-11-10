#!/usr/bin/env bash
# update.sh : chaque cible ne touche qu'à son code, vérifie que l'app redémarre et revient en arrière sinon.
source "$(dirname "$0")/banc.sh"

version() { cat "apps/$1/VERSION"; }

titre "Mise à jour complète : les 15 dépôts sont synchronisés"
banc_neuf
attendu "update.sh (tout) réussit" ./update.sh
attendu "15 dépôts clonés" test "$(find apps -mindepth 1 -maxdepth 1 -type d | wc -l)" = 15
for repo in "${DEPOTS_SIMULES[@]}"; do publier "$repo"; done
avant="$(version atelier_viz)"
attendu "update.sh (tout) réussit de nouveau" ./update.sh
attendu "toutes les apps avancent" test "$(cat apps/*/VERSION | grep -c ' 1$')" = 0
refuse "Viz a bien changé de version" test "$(version atelier_viz)" = "$avant"

titre "Une cible ne synchronise que son dépôt"
publier agent-ops-lab; publier Atelier_Projets; publier Atelier_Portefolio
projets="$(version atelier_projets)"; portfolio="$(version atelier_portefolio)"; ops="$(version agent-ops-lab)"
vider_journal
attendu "update.sh ops réussit" ./update.sh ops
refuse "Ops Lab avance" test "$(version agent-ops-lab)" = "$ops"
attendu "Projets ne bouge pas (son API n'est pas reconstruite)" test "$(version atelier_projets)" = "$projets"
attendu "Portfolio ne bouge pas (il reste à mettre à jour)" test "$(version atelier_portefolio)" = "$portfolio"
dans_journal "build ops"

titre "Un dépôt absent est cloné, cible ou non"
rm -rf apps/atelier_hub apps/atelier-tab
attendu "update.sh hub réussit" ./update.sh hub
attendu "Hub (la cible) est cloné" test -f apps/atelier_hub/VERSION
attendu "Tab (utile à l'image de Caddy) est cloné" test -f apps/atelier-tab/VERSION
attendu "Projets ne bouge toujours pas" test "$(version atelier_projets)" = "$projets"

titre "portail et ia ne synchronisent aucune app"
attendu "update.sh portail réussit" ./update.sh portail
attendu "Portfolio ne bouge pas" test "$(version atelier_portefolio)" = "$portfolio"

banc_fin
