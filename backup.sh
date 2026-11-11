#!/usr/bin/env bash
# Sauvegarde les données des apps dans backups/atelier-AAAAMMJJ-HHMM.tar.gz
# (dossier data/, .env et export de la base PostgreSQL de Nexus). Garde les 14 dernières.
# Une sauvegarde ratée sort en erreur, ne laisse aucune archive et ne supprime aucune ancienne ;
# les apps arrêtées pour la copie sont toujours relancées, même si le script est interrompu.
# Résultat de chaque passage : une ligne dans logs/backup.log.
#   sudo ./backup.sh                      nouvelle sauvegarde
#   sudo ./backup.sh verifier [archive]   relit une sauvegarde en entier (la dernière par défaut), sans rien arrêter
#   sudo ./restore.sh <archive>           la restaure
# À planifier chaque nuit :
#   echo "30 3 * * * root $(pwd)/backup.sh >> $(pwd)/logs/backup.log 2>&1" | sudo tee /etc/cron.d/atelier-backup
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"
umask 077 # l'archive contient .env et toutes les données : jamais lisible par un autre compte, même pendant sa création

if [ "${1:-}" = verifier ]; then
  # shellcheck disable=SC2012  # noms d'archives sans espace, tri par date
  archive="${2:-$(ls -1t backups/atelier-*.tar.gz 2>/dev/null | head -n1 || true)}"
  [ -n "$archive" ] && [ -f "$archive" ] || die "aucune sauvegarde à vérifier (sudo ./backup.sh en crée une)"
  liste=$(mktemp); trap 'rm -f "$liste"' EXIT
  verifier_archive "$archive" "$liste" || die "$archive est illisible ou incomplète (il y manque data/ ou .env)"
  ok "$archive : lisible en entier ($(du -h "$archive" | cut -f1), $(wc -l < "$liste") fichiers, du $(date -r "$archive" '+%F à %H:%M'))"
  if grep -qE ' nexus\.sql\.gz$' "$liste"; then ok "avec la base de Nexus"; else warn "sans la base de Nexus"; fi
  exit 0
fi
[ $# -eq 0 ] || die "Usage : sudo ./backup.sh [verifier [archive]]"

# Viz (DuckDB) n'accepte qu'un programme ; Projets, Savoir, Trésorerie, Wiki, Hub, Formulaire et Mission écrivent en
# SQLite : on les arrête quelques secondes pour une copie cohérente.
# media/ (les vidéos de Ciné) n'est pas sauvegardé : trop volumineux.
A_ARRETER=(viz projets savoir tresorerie wiki hub formulaire mission)
GARDER=14
JOURNAL="$ROOT/logs/backup.log"

stamp=$(date +%Y%m%d-%H%M)
final="backups/atelier-$stamp.tar.gz"
# Deux sauvegardes dans la même minute : la seconde ne remplace pas la première.
[ ! -e "$final" ] || final="backups/atelier-$stamp$(date +%S).tar.gz"
partiel="backups/.atelier-$stamp.partiel"
(umask 022; mkdir -p logs)
mkdir -p backups
# Dossier de travail sur le disque (et non dans /tmp, en mémoire vive sous Debian 13).
tmp=$(mktemp -d -p backups .tmp.XXXXXX)
arretes=()
resultat="interrompue avant la fin"

noter() { tourner_journal "$JOURNAL"; printf '%s  %s\n' "$(date '+%F %T')" "$*" >> "$JOURNAL"; }
echec() { resultat="$*"; die "$*"; }

# Relance ce que le script a arrêté (et seulement cela).
relancer() {
  [ ${#arretes[@]} -gt 0 ] || return 0
  if compose start "${arretes[@]}" >/dev/null; then arretes=(); return 0; fi
  warn "relance impossible : sudo docker compose start ${arretes[*]}"
  arretes=()
  return 1
}

fin() {
  local code=$?
  trap - EXIT INT TERM
  relancer || true
  rm -rf "$tmp" "$partiel"
  if [ "$code" -eq 0 ]; then noter "ok     $resultat"; else noter "ÉCHEC  $resultat (code $code)"; fi
  exit "$code"
}
trap fin EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Une mise à jour en cours relancerait les apps pendant leur copie : la sauvegarde attend qu'elle finisse.
resultat="le serveur est resté occupé par une mise à jour pendant plus d'une heure"
verrou attendre
resultat="interrompue avant la fin"

# ── Place disponible ─────────────────────────────────────────────────────────
# Besoin estimé : une fois et demie la dernière archive (à défaut, la taille de data/), plus 200 Mo de marge.
derniere="$(ls -1t backups/atelier-*.tar.gz 2>/dev/null | head -n1 || true)"
if [ -n "$derniere" ]; then besoin=$(( $(du -k "$derniere" | cut -f1) * 3 / 2 ))
else besoin="$(du -sk data 2>/dev/null | cut -f1)"; fi
besoin=$(( ${besoin:-0} + 204800 ))
libre="$(libre_ko backups)"
[ "$libre" -ge "$besoin" ] || echec "espace disque insuffisant : $((libre / 1024)) Mo libres, $((besoin / 1024)) Mo nécessaires (df -h /, sudo docker system df)"

# ── Base de Nexus ────────────────────────────────────────────────────────────
step "Export PostgreSQL (Nexus)"
complet=1
if compose exec -T postgres pg_dump -U nexus -d atelier_nexus --clean --if-exists | gzip > "$tmp/nexus.sql.gz"; then
  ok "nexus.sql.gz"
else
  # PostgreSQL arrêté ou en panne : les fichiers de data/ sont sauvegardés quand même, et le script sortira en erreur.
  warn "export de la base de Nexus impossible (sudo docker compose logs postgres) : archive faite sans lui"
  rm -f "$tmp/nexus.sql.gz"
  complet=0
fi

# ── Archive ──────────────────────────────────────────────────────────────────
step "Archive des données"
en_marche="$(compose ps --services --status running 2>/dev/null)" || en_marche="$(printf '%s\n' "${A_ARRETER[@]}")"
for service in "${A_ARRETER[@]}"; do
  if grep -qxF "$service" <<<"$en_marche"; then arretes+=("$service"); fi
done
if [ ${#arretes[@]} -gt 0 ]; then compose stop "${arretes[@]}" >/dev/null; fi

contenu=(data .env)
if [ "$complet" -eq 1 ]; then contenu+=(-C "$tmp" nexus.sql.gz); fi
code_tar=0
tar -czf "$partiel" "${contenu[@]}" || code_tar=$?
relancer || complet=0

# tar rend 1 quand un fichier a changé pendant sa lecture (une app non arrêtée écrivait) : l'archive reste utilisable.
if [ "$code_tar" -eq 1 ]; then warn "des fichiers ont changé pendant la copie"
elif [ "$code_tar" -ne 0 ]; then echec "création de l'archive impossible (tar : code $code_tar)"; fi

# L'archive ne prend son nom définitif qu'une fois relue en entier.
verifier_archive "$partiel" "$tmp/liste" || echec "archive illisible ou incomplète : rien n'est gardé"
mv -f "$partiel" "$final"
chmod 600 "$final"
taille="$(du -h "$final" | cut -f1)"
ok "$final ($taille, $(wc -l < "$tmp/liste") fichiers, relue en entier)"

if [ "$complet" -eq 1 ]; then
  # Rotation seulement après une sauvegarde complète et vérifiée : un échec ne chasse jamais une bonne archive.
  ls -1t backups/atelier-*.tar.gz | tail -n +$((GARDER + 1)) | xargs -r rm -f
  resultat="$final ($taille)"
else
  resultat="$final ($taille) INCOMPLÈTE : sans la base de Nexus ou avec une app non relancée ; anciennes archives conservées"
  die "sauvegarde incomplète : $final est gardée, les anciennes archives aussi"
fi
