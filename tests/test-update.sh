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

titre "Chaque service est attendu sur sa sonde avant d'être dit à jour"
vider_journal
attendu "update.sh ops réussit" ./update.sh ops
dans_journal "tag atelier-ops:latest atelier-ops:precedent" "l'image en service est gardée le temps de l'essai"
dans_journal "up -d --wait --wait-timeout 300 ops"
dans_journal "rmi atelier-ops:precedent" "puis libérée une fois l'app repartie"

titre "Une app qui ne redémarre pas : retour à l'image précédente"
vider_journal
sortie="$(DOCKER_FAIL_ON="up -d --wait --wait-timeout 300 ops" ./update.sh ops 2>&1)"; code=$?
attendu "update.sh ops sort en erreur" test "$code" -ne 0
dans_journal "tag atelier-ops:precedent atelier-ops:latest" "l'image précédente reprend le nom en service"
dans_journal "up -d --no-build --wait --wait-timeout 300 ops" "et elle est relancée"
attendu "le message parle de la version précédente" grep -q "version précédente a été remise en service" <<<"$sortie"
attendu "et nomme le service en échec" grep -q "non mis à jour : ops" <<<"$sortie"

titre "Une construction en échec ne touche pas à la version en service"
vider_journal
DOCKER_FAIL_ON="build ops" refuse "update.sh ops sort en erreur" ./update.sh ops
hors_journal "up -d --wait --wait-timeout 300 ops" "l'app en service n'est pas relancée"

titre "Mise à jour complète : une app en panne n'arrête pas les autres"
vider_journal
sortie="$(DOCKER_FAIL_ON="build viz" ./update.sh 2>&1)"; code=$?
attendu "update.sh sort en erreur" test "$code" -ne 0
attendu "et nomme Viz" grep -q "non mis à jour : viz" <<<"$sortie"
for service in $(grep -vx viz "$SIM/services"); do
  grep -qF "up -d --wait --wait-timeout 300 $service" "$SIM_LOG" || rouge "$service n'a pas été déployé"
done
vert "tous les autres services sont déployés"
attendu "datamind-demo passe après datamind" test "$(grep -n 'up -d --wait --wait-timeout 300 datamind' "$SIM_LOG" | tail -n1 | grep -c 'datamind-demo')" = 1

titre "Caddy et le portail ne sont reconstruits que si quelque chose les concerne a changé"
attendu "update.sh portail (les deux sont déployés et notés)" ./update.sh portail
vider_journal
attendu "update.sh ops" ./update.sh ops
dans_journal "build ops"
hors_journal "build caddy" "Caddy n'est pas reconstruit (aucune connexion coupée)"
hors_journal "build portail" "le portail non plus"
hors_journal "up -d --wait --wait-timeout 300 caddy" "Caddy n'est pas relancé"
echo "# une adresse de plus" >> caddy/Caddyfile
vider_journal
attendu "update.sh hub après une modification du Caddyfile" ./update.sh hub
dans_journal "build caddy" "Caddy est reconstruit"
hors_journal "build portail" "pas le portail"
echo "// une tuile de plus" >> portail/server.mjs
vider_journal
attendu "update.sh mission après une modification du portail" ./update.sh mission
dans_journal "build portail" "le portail est reconstruit"
hors_journal "build caddy" "pas Caddy"
sed -i 's/^PORTAL_PASSWORD=.*/PORTAL_PASSWORD=un-autre-mot-de-passe/' .env
vider_journal
attendu "update.sh portfolio après un changement de réglage du portail (.env)" ./update.sh portfolio
dans_journal "build portail" "le portail est redéployé avec le nouveau réglage"
hors_journal "build caddy" "pas Caddy"
vider_journal
echo "atelier-datamind:precedent" > "$SIM/image-retenue"   # la démo publique tourne encore sur l'ancienne image
attendu "update.sh datamind" ./update.sh datamind
dans_journal "up -d --wait --wait-timeout 300 datamind-demo" "la démo publique suit toujours DataMind"
attendu "l'ancienne image de DataMind est libérée une fois la démo relancée (elle la retenait)" \
  test "$(grep -n 'rmi atelier-datamind:precedent' "$SIM_LOG" | tail -n1 | cut -d: -f1)" -gt "$(grep -n 'up -d --wait --wait-timeout 300 datamind-demo' "$SIM_LOG" | cut -d: -f1)"
hors_journal "build caddy" "Caddy n'est pas reconstruit"
echo "# encore une adresse" >> caddy/Caddyfile
vider_journal
DOCKER_FAIL_ON="build caddy" refuse "update.sh ops avec un Caddy qui ne se construit pas" ./update.sh ops
vider_journal
attendu "update.sh ops de nouveau" ./update.sh ops
dans_journal "build caddy" "un déploiement raté n'est pas noté : Caddy est reconstruit au passage suivant"
vider_journal
attendu "update.sh portail" ./update.sh portail
dans_journal "build caddy" "la cible portail reconstruit toujours Caddy"
dans_journal "build portail" "et le portail"

titre "Cache de construction gardé entre les services d'une même cible"
vider_journal
attendu "update.sh tab" ./update.sh tab
entre="$(sed -n '/build caddy/,/build nexus-backend/p' "$SIM_LOG")"
refuse "pas de vidage du cache entre Caddy et Nexus (l'installation de Tab sert aux deux)" grep -q "builder prune" <<<"$entre"
attendu "les anciennes images sont tout de même supprimées entre les deux" grep -q "image prune" <<<"$entre"
attendu "le cache est vidé à la fin" grep -q "builder prune" <<<"$(sed -n '/build nexus-backend/,$p' "$SIM_LOG")"
vider_journal
attendu "update.sh (tout)" ./update.sh
premier="$(grep -m1 -o 'build [a-z-]*' "$SIM_LOG")"
attendu "mise à jour complète : cache vidé après chaque service (disque de 40 Go)" \
  grep -q "builder prune" <<<"$(sed -n "/$premier/,/ build /p" "$SIM_LOG" | sed '1d')"

titre "Premier lancement : aucune image à garder"
vider_journal
DOCKER_SANS_IMAGE=1 attendu "update.sh hub réussit" ./update.sh hub
hors_journal "precedent" "aucune étiquette « precedent »"

titre "Docker trop ancien : refus avant de toucher aux conteneurs"
vider_journal
DOCKER_VERSION=24.0.7 refuse "update.sh ops refuse" ./update.sh ops
hors_journal "build" "rien n'est construit"
hors_journal "up -d" "rien n'est relancé"

titre "docker-init absent : refus avant de toucher aux conteneurs (init: true ne démarrerait rien)"
vider_journal
DOCKER_SANS_INIT=1 ATELIER_DOCKER_INIT=/nulle/part/docker-init refuse "update.sh ops refuse" ./update.sh ops
hors_journal "build" "rien n'est construit"
: > "$SIM/docker-init"; chmod +x "$SIM/docker-init"
DOCKER_SANS_INIT=1 ATELIER_DOCKER_INIT="$SIM/docker-init" attendu "docker-init trouvé sur le disque : la mise à jour passe" ./update.sh ops

banc_fin
