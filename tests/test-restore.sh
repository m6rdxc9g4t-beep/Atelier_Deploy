#!/usr/bin/env bash
# restore.sh : une sauvegarde se restaure en une commande, sans rien supprimer, et une archive abîmée est refusée
# avant qu'une seule app soit arrêtée.
source "$(dirname "$0")/banc.sh"

preparer() {
  banc_neuf
  mkdir -p data/viz data/wiki
  echo "POSTGRES_PASSWORD=mot'de passe" >> .env
  echo "rapport d'origine" > data/viz/rapport.json
  echo "page d'origine" > data/wiki/page.md
  ./backup.sh >/dev/null 2>&1 || rouge "sauvegarde de départ impossible"
  archive="$(find backups -name 'atelier-*.tar.gz' | head -n1)"
  # Depuis la sauvegarde : un fichier modifié, un fichier ajouté, un réglage changé.
  echo "rapport abîmé" > data/viz/rapport.json
  echo "brouillon" > data/wiki/nouveau.md
  echo "REGLAGE_RECENT=1" >> .env
  vider_journal
}

titre "Restauration"
preparer
attendu "restore.sh réussit" ./restore.sh --oui "$archive"
attendu "le fichier modifié retrouve son contenu" test "$(cat data/viz/rapport.json)" = "rapport d'origine"
refuse "le fichier ajouté depuis n'est plus là" test -e data/wiki/nouveau.md
ancien="$(find . -maxdepth 1 -name 'data.avant-restauration-*' | head -n1)"
attendu "les données d'avant sont gardées à côté" test "$(cat "$ancien/viz/rapport.json" 2>/dev/null)" = "rapport abîmé"
attendu "la base de Nexus est rejouée" grep -q "faux export de la base de Nexus" "$SIM/psql.recu"
attendu "le mot de passe de la base suit .env (apostrophe protégée)" grep -qF "ALTER USER nexus PASSWORD 'mot''de passe';" "$SIM/psql.recu"
attendu ".env n'est pas touché" grep -q "REGLAGE_RECENT=1" .env
attendu "les apps sont arrêtées avant, relancées après" test "$(grep -n -m1 'compose --env-file .env stop' "$SIM_LOG" | cut -d: -f1)" -lt "$(grep -n 'compose --env-file .env up -d$' "$SIM_LOG" | tail -n1 | cut -d: -f1)"

titre "Restauration avec le .env de l'archive"
preparer
attendu "restore.sh --avec-env réussit" ./restore.sh --oui --avec-env "$archive"
refuse ".env revient à celui de l'archive" grep -q "REGLAGE_RECENT=1" .env
attendu "le .env d'avant est gardé à côté" grep -q "REGLAGE_RECENT=1" "$(find . -maxdepth 1 -name '.env.avant-restauration-*' | head -n1)"

titre "Archive abîmée : refus avant tout arrêt"
preparer
head -c 100 "$archive" > backups/atelier-tronquee.tar.gz
refuse "restore.sh refuse" ./restore.sh --oui backups/atelier-tronquee.tar.gz
hors_journal "stop" "aucune app n'est arrêtée"
attendu "les données ne bougent pas" test "$(cat data/viz/rapport.json)" = "rapport abîmé"

titre "Sans confirmation, rien ne se passe"
refuse "restore.sh sans --oui (hors terminal) refuse" ./restore.sh "$archive" </dev/null
hors_journal "stop" "aucune app n'est arrêtée"

titre "Disque trop plein pour garder les données actuelles : refus avant tout arrêt"
DF_LIBRE_KO=1024 refuse "restore.sh refuse" ./restore.sh --oui "$archive"
hors_journal "stop" "aucune app n'est arrêtée"

titre "Extraction en panne : les données actuelles reprennent leur place"
preparer
ARCHIVE_ILLISIBLE_A_L_EXTRACTION=1 refuse "restore.sh sort en erreur" ./restore.sh --oui "$archive"
attendu "data/ est celui d'avant" test "$(cat data/viz/rapport.json)" = "rapport abîmé"
dans_journal "up -d" "les apps sont relancées"

titre "backup.sh verifier"
preparer
attendu "la dernière sauvegarde est reconnue bonne" ./backup.sh verifier
attendu "une archive nommée aussi" ./backup.sh verifier "$archive"
head -c 100 "$archive" > backups/atelier-tronquee.tar.gz
refuse "une archive tronquée est signalée" ./backup.sh verifier backups/atelier-tronquee.tar.gz
hors_journal "stop" "vérifier n'arrête aucune app"

banc_fin
