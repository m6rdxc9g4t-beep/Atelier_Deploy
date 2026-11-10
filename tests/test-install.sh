#!/usr/bin/env bash
# install.sh sur le banc : apt-get, curl, dig, swapon et ufw sont simulés, rien n'est installé sur la machine.
# Demande root (comme le vrai script) : sauté sinon.
source "$(dirname "$0")/banc.sh"
if [ "$(id -u)" -ne 0 ]; then echo "install.sh exige root : test sauté"; exit 0; fi

preparer() {
  banc_neuf
  local outil
  for outil in apt-get fallocate mkswap systemctl; do printf '#!/usr/bin/env bash\nexit 0\n' > "$SIM/bin/$outil"; done
  printf '#!/usr/bin/env bash\necho "203.0.113.10"\n' > "$SIM/bin/curl"              # adresse publique du VPS
  printf '#!/usr/bin/env bash\necho "203.0.113.10"\n' > "$SIM/bin/dig"               # tous les sous-domaines pointent dessus
  printf '#!/usr/bin/env bash\necho "/swapfile file 4G 0B -2"\n' > "$SIM/bin/swapon" # swap déjà là : aucune création
  printf '#!/usr/bin/env bash\necho "Status: inactive"\n' > "$SIM/bin/ufw"           # pare-feu inactif : aucune règle
  chmod +x "$SIM/bin/"*
}

titre "Installation"
preparer
sortie="$(./install.sh </dev/null 2>&1)"; code=$?
attendu "install.sh réussit" test "$code" -eq 0
attendu "les 15 dépôts sont clonés" test "$(find apps -mindepth 1 -maxdepth 1 -type d | wc -l)" = 15
attendu "les secrets manquants sont générés" grep -q '^SESSION_SECRET=.\{32,\}' .env
attendu ".env n'est lisible que par root" test "$(stat -c %a .env)" = 600
for hote in wiki hub formulaire convert mission; do
  grep -q "$hote.atelier.exemple.test → 203.0.113.10" <<<"$sortie" || rouge "DNS de $hote non vérifié"
done
vert "le DNS de chaque site servi par Caddy est vérifié (Wiki, Hub et Formulaire compris)"
refuse "aucune construction de tout d'un coup" grep -qx "docker compose --env-file .env build" "$SIM_LOG"
for service in $(cat "$SIM/services"); do
  grep -qF "up -d --wait --wait-timeout 300 $service" "$SIM_LOG" || rouge "$service n'a pas été déployé"
done
vert "chaque service est construit puis attendu, un par un"
attendu "datamind-demo passe après datamind" test "$(grep -n 'up -d --wait --wait-timeout 300 datamind' "$SIM_LOG" | tail -n1 | grep -c 'datamind-demo')" = 1
attendu "le récapitulatif donne l'adresse du portail" grep -q "https://atelier.exemple.test" <<<"$sortie"

titre "Relance sur un VPS déjà installé : rien n'est perdu"
secret="$(grep '^SESSION_SECRET=' .env)"; mkdir -p data/viz; echo "rapport" > data/viz/rapport.json
attendu "install.sh réussit de nouveau" ./install.sh </dev/null
attendu "les secrets ne changent pas" grep -qxF "$secret" .env
attendu "les données sont intactes" test "$(cat data/viz/rapport.json)" = "rapport"

titre "Une app qui ne se construit pas n'empêche pas les autres de démarrer"
preparer
sortie="$(DOCKER_FAIL_ON="build viz" ./install.sh </dev/null 2>&1)"; code=$?
attendu "install.sh sort en erreur" test "$code" -ne 0
attendu "et nomme Viz" grep -q "viz" <<<"$(grep -i "pas pu" <<<"$sortie")"
dans_journal "up -d --wait --wait-timeout 300 portail" "le portail est déployé"
dans_journal "up -d --wait --wait-timeout 300 wiki" "le Wiki aussi"

titre "Docker trop ancien : refus avant toute construction"
preparer
DOCKER_VERSION=24.0.7 refuse "install.sh refuse" ./install.sh </dev/null
hors_journal "build" "rien n'est construit"

banc_fin
