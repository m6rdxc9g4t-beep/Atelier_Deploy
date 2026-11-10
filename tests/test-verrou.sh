#!/usr/bin/env bash
# Verrou commun : mise à jour, mise à jour automatique, sauvegarde et restauration ne tournent jamais en même temps.
source "$(dirname "$0")/banc.sh"

# Attend (20 s au plus) qu'un appel à docker apparaisse dans le journal.
attendre_journal() { for _ in $(seq 1 100); do grep -qF -- "$1" "$SIM_LOG" && return 0; sleep 0.2; done; return 1; }

titre "Pendant une mise à jour"
banc_neuf
mkdir -p data && echo "x" > data/fichier
attendu "installation simulée (update.sh)" ./update.sh
attendu "sauvegarde de départ" ./backup.sh
archive="$(find backups -name 'atelier-*.tar.gz' | head -n1)"
publier agent-ops-lab
vider_journal
DOCKER_SLEEP_ON="build ops" DOCKER_SLEEP=6 ./update.sh ops >"$SIM/maj.log" 2>&1 &
maj=$!
attendu "la première mise à jour est en cours" attendre_journal "build ops"
sortie="$(./update.sh viz 2>&1)"; code=$?
attendu "une seconde mise à jour est refusée tout de suite" test "$code" -ne 0
attendu "avec un message clair" grep -q "déjà en cours" <<<"$sortie"
hors_journal "build viz" "elle n'a rien construit"
sortie="$(./auto-update.sh 2>&1)"; code=$?
attendu "le passage du cron sort sans erreur ni bruit" test "$code" -eq 0 -a -z "$sortie"
sortie="$(./restore.sh --oui "$archive" 2>&1)"; code=$?
attendu "une restauration est refusée" test "$code" -ne 0
attendu "à cause du verrou, avant tout arrêt" grep -q "déjà en cours" <<<"$sortie"
./backup.sh >"$SIM/sauvegarde.log" 2>&1 &
sauvegarde=$!
sleep 1
hors_journal "stop" "la sauvegarde attend : aucune app arrêtée pendant la mise à jour"
wait "$maj"; attendu "la mise à jour se termine bien" test $? -eq 0
wait "$sauvegarde"; attendu "puis la sauvegarde s'exécute" test $? -eq 0
attendu "une seconde archive est là" test "$(find backups -name 'atelier-*.tar.gz' | wc -l)" = 2
attendu "la sauvegarde a commencé après la fin de la mise à jour" test "$(grep -n 'compose --env-file .env ps$' "$SIM_LOG" | tail -n1 | cut -d: -f1)" -lt "$(grep -n 'pg_dump' "$SIM_LOG" | head -n1 | cut -d: -f1)"

titre "Le verrou ne survit pas à son script"
attendu "une mise à jour repart ensuite" ./update.sh ops
# Dans son propre groupe de processus, pour pouvoir le tuer avec ses enfants (le faux docker endormi).
DOCKER_SLEEP_ON="build ops" DOCKER_SLEEP=30 setsid ./update.sh ops >/dev/null 2>&1 &
maj=$!
vider_journal
attendu "mise à jour en cours" attendre_journal "build ops"
refuse "le verrou est pris" ./update.sh viz
kill -KILL -- "-$maj" 2>/dev/null; wait "$maj" 2>/dev/null
sleep 0.5
attendu "un script tué libère le verrou" ./update.sh viz

titre "auto-update.sh appelle update.sh sans se bloquer lui-même"
publier agent-ops-lab
vider_journal
attendu "auto-update.sh réussit" ./auto-update.sh
dans_journal "build ops"

banc_fin
