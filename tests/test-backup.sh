#!/usr/bin/env bash
# backup.sh : une sauvegarde ratée ne passe jamais pour réussie, ne détruit rien, et les apps repartent toujours.
source "$(dirname "$0")/banc.sh"

preparer() {
  banc_neuf
  mkdir -p data/viz data/projets backups
  echo "rapport" > data/viz/rapport.json
  echo "base" > data/projets/atelier.db
}
archives() { find backups -maxdepth 1 -name 'atelier-*.tar.gz' | wc -l; }

titre "Sauvegarde normale"
preparer
attendu "backup.sh réussit" ./backup.sh
archive="$(ls backups/atelier-*.tar.gz 2>/dev/null | head -n1)"
attendu "une archive est créée" test -s "$archive"
liste="$(tar -tzf "$archive" 2>/dev/null)"
attendu "elle contient data/" grep -q '^data/viz/rapport.json$' <<<"$liste"
attendu "elle contient .env" grep -qx '.env' <<<"$liste"
attendu "elle contient l'export de Nexus" grep -qx 'nexus.sql.gz' <<<"$liste"
attendu "elle n'est lisible que par root (600)" test "$(stat -c %a "$archive")" = 600
dans_journal "stop viz projets savoir tresorerie wiki hub formulaire mission" "les apps à base de fichiers sont arrêtées, Projets compris"
dans_journal "start viz projets savoir tresorerie wiki hub formulaire mission" "puis relancées"
attendu "aucun fichier temporaire ne reste" test -z "$(find backups -mindepth 1 ! -name 'atelier-*.tar.gz')"
attendu "le journal garde une ligne" grep -q "ok" logs/backup.log

titre "Une app arrêtée à la main n'est pas relancée"
preparer
grep -vx hub "$SIM/services" > "$SIM/en-marche"
attendu "backup.sh réussit" ./backup.sh
dans_journal "start viz projets savoir tresorerie wiki formulaire mission" "seules les apps arrêtées par le script repartent"
hors_journal "hub formulaire" "Hub, arrêté avant la sauvegarde, reste arrêté"

titre "A. tar en échec (disque plein)"
preparer
for i in 01 02 03; do echo "ancienne $i" > "backups/atelier-202601$i-0330.tar.gz"; done
TAR_FAIL=1 refuse "backup.sh sort en erreur" ./backup.sh
attendu "aucune nouvelle archive" test "$(archives)" = 3
attendu "aucune archive vide ni partielle" test -z "$(find backups -mindepth 1 ! -name 'atelier-202601*')"
dans_journal "start viz projets" "les apps sont relancées malgré l'échec"
attendu "le journal note l'échec" grep -q "ÉCHEC" logs/backup.log

titre "A bis. quatorze nuits d'échec ne suppriment aucune ancienne sauvegarde"
for _ in $(seq 1 14); do TAR_FAIL=1 ./backup.sh >/dev/null 2>&1 || true; done
attendu "les 3 anciennes archives sont intactes" test "$(archives)" = 3

titre "B. PostgreSQL arrêté"
preparer
DOCKER_FAIL_ON="pg_dump" refuse "backup.sh sort en erreur" ./backup.sh
archive="$(ls backups/atelier-*.tar.gz 2>/dev/null | head -n1)"
attendu "data/ est archivé quand même" grep -q '^data/viz/rapport.json$' <<<"$(tar -tzf "$archive" 2>/dev/null)"
refuse "sans export de Nexus" grep -qx 'nexus.sql.gz' <<<"$(tar -tzf "$archive" 2>/dev/null)"
dans_journal "start viz projets" "les apps sont relancées"

titre "B bis. une archive incomplète ne chasse pas les anciennes"
preparer
for i in $(seq 10 24); do echo "ancienne" > "backups/atelier-202601$i-0330.tar.gz"; touch -d "2026-01-$i" "backups/atelier-202601$i-0330.tar.gz"; done
DOCKER_FAIL_ON="pg_dump" ./backup.sh >/dev/null 2>&1 || true
attendu "les 15 anciennes archives restent" test "$(archives)" = 16

titre "C. interruption pendant l'archive (SIGTERM)"
preparer
TAR_SLEEP=2 ./backup.sh >/dev/null 2>&1 &
pid=$!
sleep 1; kill -TERM "$pid"; wait "$pid"; code=$?
attendu "backup.sh sort en erreur (code $code)" test "$code" -ne 0
dans_journal "stop viz projets" "les apps avaient été arrêtées"
dans_journal "start viz projets" "elles sont relancées avant de sortir"
attendu "aucune archive n'est laissée" test -z "$(find backups -mindepth 1)"

titre "Rotation : 14 archives gardées après une sauvegarde vérifiée"
preparer
for i in $(seq 10 24); do echo "ancienne" > "backups/atelier-202601$i-0330.tar.gz"; touch -d "2026-01-$i" "backups/atelier-202601$i-0330.tar.gz"; done
attendu "backup.sh réussit" ./backup.sh
attendu "14 archives restent" test "$(archives)" = 14
refuse "la plus ancienne est partie" test -e backups/atelier-20260110-0330.tar.gz

titre "Disque presque plein : refus avant d'arrêter quoi que ce soit"
preparer
DF_LIBRE_KO=1024 refuse "backup.sh refuse" ./backup.sh
hors_journal "stop" "aucune app n'est arrêtée"

banc_fin
