#!/usr/bin/env bash
# Sauvegarde les données des apps dans backups/atelier-AAAAMMJJ-HHMM.tar.gz
# (dossier data/ + export de la base PostgreSQL de Nexus). Garde les 14 dernières.
# À planifier chaque nuit :  echo "30 3 * * * root $(pwd)/backup.sh >/dev/null" | sudo tee /etc/cron.d/atelier-backup
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"

stamp=$(date +%Y%m%d-%H%M)
mkdir -p backups
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

step "Export PostgreSQL (Nexus)"
compose exec -T postgres pg_dump -U nexus -d atelier_nexus --clean --if-exists | gzip > "$tmp/nexus.sql.gz"
ok "nexus.sql.gz"

step "Archive des données"
# Viz (DuckDB) n'accepte qu'un programme, Savoir et Trésorerie écrivent en SQLite :
# on les arrête quelques secondes pour une copie cohérente.
# media/ (les vidéos de Ciné) n'est pas sauvegardé : trop volumineux.
compose stop viz savoir tresorerie >/dev/null
tar -czf "backups/atelier-$stamp.tar.gz" data .env -C "$tmp" nexus.sql.gz || true
compose start viz savoir tresorerie >/dev/null
chmod 600 "backups/atelier-$stamp.tar.gz"
ok "backups/atelier-$stamp.tar.gz ($(du -h "backups/atelier-$stamp.tar.gz" | cut -f1))"

ls -1t backups/atelier-*.tar.gz | tail -n +15 | xargs -r rm -f
