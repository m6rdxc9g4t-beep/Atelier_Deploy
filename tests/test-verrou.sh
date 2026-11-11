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

titre "Un script lancé par une ancienne version du kit (verrou d'alors, ailleurs) prend le verrou actuel"
vider_journal
DOCKER_SLEEP_ON="build ops" DOCKER_SLEEP=4 ATELIER_VERROU=1 ./update.sh ops >/dev/null 2>&1 &
maj=$!
attendu "mise à jour en cours" attendre_journal "build ops"
refuse "une seconde mise à jour est refusée" ./update.sh viz
wait "$maj"; attendu "la première se termine bien" test $? -eq 0

titre "Le verrou par défaut vit là où seul root peut créer un fichier"
attendu "/run/atelier.lock, et non /run/lock (ouvert en écriture à tous)" \
  test "$(env -u ATELIER_VERROU_FICHIER bash -c 'source scripts/lib.sh; echo "$VERROU"')" = /run/atelier.lock

# Sans droit d'écriture sur le verrou : sous root, un autre identifiant dans un espace de noms (root écrit partout).
sans_droits() { "$@"; }
if [ "$(id -u)" -eq 0 ]; then
  if unshare -U --map-user=1000 --map-group=1000 true 2>/dev/null; then sans_droits() { unshare -U --map-user=1000 --map-group=1000 "$@"; }
  else sans_droits() { return 77; }; fi
fi
if sans_droits true; then
  titre "Un verrou qui existe est ouvert sans écriture"
  mkdir "$SIM/verrou"; : > "$SIM/verrou/atelier.lock"; chmod 444 "$SIM/verrou/atelier.lock"; chmod 555 "$SIM/verrou"
  export ATELIER_VERROU_FICHIER="$SIM/verrou/atelier.lock"
  sans_droits bash -c 'source scripts/lib.sh; verrou refuser; echo "verrou pris"; sleep 3' >"$SIM/tenu.log" 2>&1 &
  tenu=$!
  sleep 1
  attendu "un script qui ne peut pas écrire dans le fichier prend tout de même le verrou" grep -q "verrou pris" "$SIM/tenu.log"
  refuse "sans avertissement" grep -q "indisponible" "$SIM/tenu.log"
  sortie="$(bash -c 'source scripts/lib.sh; verrou refuser; echo "suite"' 2>&1)"
  attendu "et un second script est refusé pendant ce temps" grep -q "déjà en cours" <<<"$sortie"
  wait "$tenu"

  titre "Verrou absent, impossible à créer (script lancé sans sudo) : avertissement, rien n'est créé"
  chmod 755 "$SIM/verrou"; rm -f "$SIM/verrou/atelier.lock"; chmod 555 "$SIM/verrou"
  sortie="$(sans_droits bash -c 'source scripts/lib.sh; verrou refuser; echo "suite"' 2>&1)"
  attendu "le script continue" grep -q "suite" <<<"$sortie"
  attendu "en le disant" grep -q "verrou indisponible" <<<"$sortie"
  refuse "aucun fichier de verrou n'est créé" test -e "$SIM/verrou/atelier.lock"
  chmod 755 "$SIM/verrou"
  export ATELIER_VERROU_FICHIER="$SIM/atelier.lock"
else
  printf '\n── Verrou sans droit d'"'"'écriture : sauté (unshare indisponible sous root)\n'
fi

titre "auto-update.sh appelle update.sh sans se bloquer lui-même"
publier agent-ops-lab
vider_journal
attendu "auto-update.sh réussit" ./auto-update.sh
dans_journal "build ops"

banc_fin
