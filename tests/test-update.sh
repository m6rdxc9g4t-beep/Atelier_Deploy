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
ops="$(version agent-ops-lab)"
publier agent-ops-lab
vider_journal
sortie="$(DOCKER_FAIL_ON="up -d --wait --wait-timeout 300 ops" ./update.sh ops 2>&1)"; code=$?
attendu "update.sh ops sort en erreur" test "$code" -ne 0
attendu "le code d'Ops Lab revient au commit en service" test "$(version agent-ops-lab)" = "$ops"
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

titre "Projets : l'API ne redémarre pas, l'interface servie par Caddy n'avance pas non plus"
publier Atelier_Projets
projets="$(version atelier_projets)"
vider_journal
sortie="$(DOCKER_FAIL_ON="up -d --wait --wait-timeout 300 projets" ./update.sh projets 2>&1)"; code=$?
attendu "update.sh projets sort en erreur" test "$code" -ne 0
dans_journal "up -d --no-build --wait --wait-timeout 300 projets" "l'API précédente est remise en service"
hors_journal "build caddy" "Caddy n'est pas reconstruit : pas de nouvelle interface devant l'ancienne API"
hors_journal "up -d --wait --wait-timeout 300 caddy" "ni relancé"
attendu "le code de Projets revient au commit en service" test "$(version atelier_projets)" = "$projets"
attendu "le message nomme l'API et Caddy" grep -q "non mis à jour : projets caddy" <<<"$sortie"
attendu "et dit que l'app reste sur sa version précédente" grep -q "reste sur sa version précédente" <<<"$sortie"
refuse "il ne dit plus que les autres services sont à jour" grep -q "les autres services demandés sont à jour" <<<"$sortie"
echo "# une adresse" >> caddy/Caddyfile
vider_journal
attendu "update.sh ops, qui reconstruit Caddy pour le kit" ./update.sh ops
dans_journal "build caddy"
attendu "Caddy est reconstruit avec l'interface en service, pas la nouvelle" test "$(version atelier_projets)" = "$projets"

titre "Projets : Caddy ne se construit pas, l'API déjà relancée revient à la version précédente"
vider_journal
DOCKER_FAIL_ON="build caddy" refuse "update.sh projets sort en erreur" ./update.sh projets
attendu "l'API était passée à la nouvelle version" test "$(compte_journal 'up -d --wait --wait-timeout 300 projets')" = 1
attendu "puis son image précédente reprend le nom en service" \
  test "$(grep -n 'tag atelier-projets:precedent atelier-projets:latest' "$SIM_LOG" | cut -d: -f1)" -gt "$(grep -n 'build caddy' "$SIM_LOG" | cut -d: -f1)"
dans_journal "up -d --no-build --wait --wait-timeout 300 projets" "et elle est relancée"
attendu "le code de Projets revient au commit en service" test "$(version atelier_projets)" = "$projets"
vider_journal
attendu "update.sh projets réussit ensuite" ./update.sh projets
refuse "Projets avance" test "$(version atelier_projets)" = "$projets"
attendu "l'image précédente de l'API n'est libérée qu'une fois Caddy reparti" \
  test "$(grep -n 'rmi atelier-projets:precedent' "$SIM_LOG" | cut -d: -f1)" -gt "$(grep -n 'up -d --wait --wait-timeout 300 caddy' "$SIM_LOG" | cut -d: -f1)"

titre "Nexus : le frontend ne redémarre pas, le backend revient avec lui"
publier Atelier_Nexus
nexus="$(version atelier_nexus)"
vider_journal
sortie="$(DOCKER_FAIL_ON="up -d --wait --wait-timeout 300 nexus-frontend" ./update.sh nexus 2>&1)"; code=$?
attendu "update.sh nexus sort en erreur" test "$code" -ne 0
dans_journal "tag atelier-nexus-backend:precedent atelier-nexus-backend:latest" "l'image précédente du backend reprend le nom en service"
dans_journal "up -d --no-build --wait --wait-timeout 300 nexus-backend" "et il est relancé"
attendu "le code de Nexus revient au commit en service" test "$(version atelier_nexus)" = "$nexus"
attendu "le message nomme les deux services" grep -q "non mis à jour : nexus-frontend nexus-backend" <<<"$sortie"

titre "Tab : Nexus ne se construit pas, Caddy revient à l'interface précédente"
publier atelier-tab
tab="$(version atelier-tab)"
vider_journal
DOCKER_FAIL_ON="build nexus-backend" refuse "update.sh tab sort en erreur" ./update.sh tab
dans_journal "tag atelier-caddy:precedent atelier-caddy:latest" "l'image précédente de Caddy reprend le nom en service"
dans_journal "up -d --no-build --wait --wait-timeout 300 caddy" "et il est relancé"
attendu "le code de Tab revient au commit en service" test "$(version atelier-tab)" = "$tab"
refuse "Caddy n'est plus noté à jour" test -e logs/empreinte-caddy
vider_journal
attendu "update.sh ops" ./update.sh ops
dans_journal "build caddy" "Caddy est reconstruit au passage suivant"

titre "DataMind : la démo publique ne redémarre pas, DataMind et sa démo reviennent à la version précédente"
publier Agent_Data
datamind="$(version agent_data)"
vider_journal
DOCKER_FAIL_ON="up -d --wait --wait-timeout 300 datamind-demo" refuse "update.sh datamind sort en erreur" ./update.sh datamind
dans_journal "tag atelier-datamind:precedent atelier-datamind:latest" "l'image précédente de DataMind reprend le nom en service"
dans_journal "up -d --no-build --wait --wait-timeout 300 datamind" "DataMind est relancé dessus"
dans_journal "up -d --no-build --wait --wait-timeout 300 datamind-demo" "sa démo aussi"
attendu "le code de DataMind revient au commit en service" test "$(version agent_data)" = "$datamind"

titre "Caddy, qui n'accompagne Ops Lab que pour le kit, échoue : Ops Lab reste à jour"
publier agent-ops-lab
ops="$(version agent-ops-lab)"
echo "# une autre adresse" >> caddy/Caddyfile
vider_journal
sortie="$(DOCKER_FAIL_ON="build caddy" ./update.sh ops 2>&1)"; code=$?
attendu "update.sh ops sort en erreur" test "$code" -ne 0
refuse "Ops Lab avance" test "$(version agent-ops-lab)" = "$ops"
hors_journal "atelier-ops:precedent atelier-ops:latest" "son image n'est pas remise en arrière"
attendu "le message nomme Caddy seul" grep -q "non mis à jour : caddy (voir plus haut ; les autres services demandés sont à jour)" <<<"$sortie"
attendu "update.sh ops réussit ensuite" ./update.sh ops

titre "Mise à jour complète, une app jamais construite ne se construit pas : le message la nomme"
vider_journal
sortie="$(DOCKER_SANS_IMAGE=1 DOCKER_FAIL_ON="build viz" ./update.sh 2>&1)"; code=$?
attendu "update.sh sort en erreur" test "$code" -ne 0
attendu "et nomme Viz" grep -q "non mis à jour : viz" <<<"$sortie"
attendu "la relance finale ne reconstruit rien" test "$(compte_journal 'up -d --no-build --remove-orphans')" = 1
refuse "et laisse Viz de côté" grep -q -- "up -d --no-build --remove-orphans.* viz" "$SIM_LOG"
dans_journal "up -d --wait --wait-timeout 300 wiki" "les autres apps sont déployées"

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

titre "Nexus réglé sur Claude : gardé avec le jeton du forfait, ramené à l'IA du serveur sans accès à Claude ; ligne du jeton ajoutée à un .env d'avant"
# .env d'avant le jeton du forfait : sans sa ligne (les passages précédents l'ont ajoutée).
grep -v -e '^CLAUDE_OAUTH_TOKEN=' -e 'Claude avec ton forfait' .env > "$SIM/env.avant"
cp "$SIM/env.avant" .env
echo "NEXUS_LLM_PROVIDER=anthropic" >> .env
attendu "update.sh ops réussit (ni clé ni jeton)" ./update.sh ops
attendu "sans clé ni jeton : Nexus revient à l'IA du serveur" grep -qx "NEXUS_LLM_PROVIDER=ollama" .env
cp "$SIM/env.avant" .env
printf '%s\n' "CLAUDE_OAUTH_TOKEN=sk-ant-oat01-jeton-de-test" "NEXUS_LLM_PROVIDER=anthropic" >> .env
attendu "update.sh ops réussit (jeton du forfait seul)" ./update.sh ops
attendu "avec le jeton du forfait : Claude reste le moteur par défaut de Nexus" grep -qx "NEXUS_LLM_PROVIDER=anthropic" .env
attendu "et le jeton est laissé tel quel dans .env" grep -qx "CLAUDE_OAUTH_TOKEN=sk-ant-oat01-jeton-de-test" .env
cp "$SIM/env.avant" .env
refuse "le .env du banc est bien un .env d'avant (sans ligne de jeton)" grep -q "^CLAUDE_OAUTH_TOKEN=" .env
sortie="$(./update.sh ops 2>&1)"; code=$?
attendu "sans la ligne CLAUDE_OAUTH_TOKEN (.env d'avant) : update.sh ops réussit" test "$code" -eq 0
attendu "la ligne CLAUDE_OAUTH_TOKEN= est ajoutée, vide (le jeton se colle au bon endroit)" grep -qx "CLAUDE_OAUTH_TOKEN=" .env
attendu "et l'ajout est annoncé" grep -q "CLAUDE_OAUTH_TOKEN= ajoutée" <<<"$sortie"
refuse "le jeton propre à DataMind n'est pas touché" grep -q "DATAMIND_CLAUDE_OAUTH_TOKEN" .env
attendu "un second passage ne la double pas" ./update.sh ops
attendu "une seule ligne CLAUDE_OAUTH_TOKEN=" test "$(grep -c '^CLAUDE_OAUTH_TOKEN=' .env)" = 1
attendu "les autres réglages sont gardés" grep -qx "OLLAMA_MODEL=llama3.2:1b" .env
cp "$SIM/env.avant" .env
printf '%s\n' "CLAUDE_OAUTH_TOKEN=sk-ant-oat01-jeton-de-test" >> .env
attendu "update.sh ops réussit (jeton déjà présent)" ./update.sh ops
attendu "un jeton déjà présent n'est jamais vidé ni doublé" test "$(grep -c '^CLAUDE_OAUTH_TOKEN=' .env)" = 1
attendu "il reste tel quel" grep -qx "CLAUDE_OAUTH_TOKEN=sk-ant-oat01-jeton-de-test" .env

banc_fin
