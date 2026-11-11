#!/usr/bin/env bash
# Restaure une sauvegarde faite par backup.sh : les données des apps (data/) et la base de Nexus.
#
#   sudo ./restore.sh                                  liste les sauvegardes disponibles
#   sudo ./restore.sh backups/atelier-AAAAMMJJ-HHMM.tar.gz
#       --avec-env   remet aussi le .env de l'archive (l'actuel est gardé à côté)
#       --oui        ne demande pas de confirmation
#
# Rien n'est supprimé : les données actuelles sont renommées data.avant-restauration-<date>.
# Une archive illisible ou incomplète est refusée avant qu'une seule app soit arrêtée.
# Nouveau VPS : voir « Restaurer » dans le README (le .env de l'archive se pose avant install.sh).
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"

archive=""; avec_env=0; oui=0
for arg in "$@"; do
  case "$arg" in
    --avec-env) avec_env=1 ;;
    --oui) oui=1 ;;
    -*) die "Option inconnue : $arg (--avec-env, --oui)" ;;
    *) archive="$arg" ;;
  esac
done

if [ -z "$archive" ]; then
  step "Sauvegardes disponibles"
  # shellcheck disable=SC2012  # noms d'archives sans espace, tri par date
  ls -1t backups/atelier-*.tar.gz 2>/dev/null | while read -r f; do
    printf '  %s  %6s  %s\n' "$(date -r "$f" '+%F %H:%M')" "$(du -h "$f" | cut -f1)" "$f"
  done
  [ -n "$(find backups -maxdepth 1 -name 'atelier-*.tar.gz' 2>/dev/null)" ] || warn "aucune (sudo ./backup.sh en crée une)"
  printf '\nRestaurer :  sudo ./restore.sh <archive>\n'
  exit 0
fi
# Le script travaille depuis le dossier du kit : un chemin relatif donné depuis ailleurs est repris tel quel s'il existe.
[ -f "$archive" ] || die "Archive introuvable : $archive (sudo ./restore.sh liste les sauvegardes)"

stamp=$(date +%Y%m%d-%H%M%S)
ancien="data.avant-restauration-$stamp"
tmp=$(mktemp -d -p "$ROOT" .restauration.XXXXXX)
arrete=0      # les apps ont été arrêtées
deplace=0     # data/ a été renommé
extrait=0     # l'archive a été extraite en entier

fin() {
  local code=$?
  trap - EXIT INT TERM
  rm -rf "$tmp"
  if [ "$deplace" -eq 1 ] && [ "$extrait" -eq 0 ]; then
    # Extraction interrompue : les données d'avant reprennent leur place.
    rm -rf data
    mv "$ancien" data
    warn "restauration annulée : les données actuelles ont été remises en place"
  fi
  if [ "$arrete" -eq 1 ] && [ "$code" -ne 0 ]; then
    compose up -d >/dev/null 2>&1 || warn "relance des apps impossible : sudo docker compose up -d"
  fi
  exit "$code"
}
trap fin EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ── 1. Contrôles, avant de toucher à quoi que ce soit ───────────────────────
step "Contrôle de l'archive"
verifier_archive "$archive" "$tmp/liste" || die "$archive est illisible ou incomplète (il y manque data/ ou .env) : rien n'a été touché"
avec_nexus=0
if grep -qE ' nexus\.sql\.gz$' "$tmp/liste"; then avec_nexus=1; fi
besoin=$(( $(awk '{ s += $3 } END { printf "%d", s / 1024 }' "$tmp/liste") + 204800 ))
libre="$(libre_ko "$ROOT")"
[ "$libre" -ge "$besoin" ] || die "espace disque insuffisant pour garder les données actuelles à côté : $((libre / 1024)) Mo libres, $((besoin / 1024)) Mo nécessaires"
compose ps >/dev/null 2>&1 || die "Docker ne répond pas : lance ce script avec sudo (sudo ./restore.sh $archive)"
ok "$archive : lisible, $(wc -l < "$tmp/liste") fichiers, du $(date -r "$archive" '+%F à %H:%M')"
if [ "$avec_nexus" -eq 1 ]; then ok "avec la base de Nexus"; else warn "sans la base de Nexus : elle ne sera pas modifiée"; fi

printf '\n  Les apps vont être arrêtées quelques minutes.\n'
printf '  data/ sera remplacé par le contenu de l'"'"'archive ; les données actuelles seront gardées dans %s/.\n' "$ancien"
if [ "$avec_nexus" -eq 1 ]; then printf '  La base de Nexus sera remplacée par celle de l'"'"'archive.\n'; fi
if [ "$avec_env" -eq 1 ]; then printf '  .env sera remplacé par celui de l'"'"'archive (l'"'"'actuel gardé dans .env.avant-restauration-%s).\n' "$stamp"; fi
if [ "$oui" -eq 0 ]; then
  [ -t 0 ] || die "Confirmation impossible hors d'un terminal : ajoute --oui pour restaurer sans question."
  read -rp "  Restaurer ? (oui/non) : " reponse
  [ "$reponse" = "oui" ] || die "Restauration abandonnée : rien n'a été touché."
fi

verrou refuser

# ── 2. Données ───────────────────────────────────────────────────────────────
step "Arrêt des apps"
arrete=1
compose stop >/dev/null
ok "apps arrêtées"

step "Données"
if [ -d data ]; then mv data "$ancien"; deplace=1; fi
tar -xzf "$archive" -C "$ROOT" data || die "extraction impossible"
extrait=1
ok "data/ restauré (données d'avant : $ancien/)"
if [ "$avec_env" -eq 1 ]; then
  cp -p .env ".env.avant-restauration-$stamp"
  tar -xzf "$archive" -C "$ROOT" .env || die "extraction de .env impossible (l'ancien : .env.avant-restauration-$stamp)"
  chmod 600 .env
  ok ".env restauré (celui d'avant : .env.avant-restauration-$stamp)"
fi
ensure_dirs

# ── 3. Base de Nexus ─────────────────────────────────────────────────────────
# Rejeu en une seule transaction, arrêtée à la première erreur : la base est remplacée en entier par celle de
# l'archive, ou reste telle qu'elle était (sans ON_ERROR_STOP, psql rendrait 0 après un rejeu à moitié raté).
# Le schéma public est vidé d'abord, dans la même transaction : une table apparue depuis la sauvegarde (mise à jour
# de Nexus) et liée aux autres par une clé étrangère empêcherait sinon de les remplacer. L'export recrée tout,
# extension vector comprise ; Nexus est arrêté, personne d'autre n'utilise la base.
rejouer_base() {
  { printf 'SET client_min_messages = warning;\nDROP SCHEMA IF EXISTS public CASCADE;\nCREATE SCHEMA public;\n'; gunzip -c "$tmp/nexus.sql.gz"; } \
    | compose exec -T postgres psql -q -v ON_ERROR_STOP=1 --single-transaction -U nexus -d atelier_nexus >/dev/null
}
incomplet=0
if [ "$avec_nexus" -eq 1 ]; then
  step "Base de Nexus"
  tar -xzf "$archive" -C "$tmp" nexus.sql.gz
  # Un export tronqué, rejoué jusqu'à sa coupure, serait validé comme une base complète : il est relu avant.
  if ! gunzip -t "$tmp/nexus.sql.gz" 2>/dev/null; then
    warn "l'export de la base de Nexus (nexus.sql.gz) est abîmé : la base n'a pas été modifiée"
    incomplet=1
  elif compose up -d --wait --wait-timeout 120 postgres >/dev/null && rejouer_base; then
    ok "base rejouée"
    # Le mot de passe de la base suit celui de .env (utile si .env vient d'être restauré).
    mdp="$(env_get POSTGRES_PASSWORD)"
    if [ -n "$mdp" ]; then
      printf "ALTER USER nexus PASSWORD '%s';\n" "${mdp//\'/\'\'}" | compose exec -T postgres psql -q -U nexus -d atelier_nexus >/dev/null \
        || warn "mot de passe de la base non aligné sur .env"
    fi
  else
    warn "la base de Nexus n'a pas pu être rejouée : elle est restée telle qu'elle était (sudo docker compose logs postgres) ; l'export est dans l'archive : nexus.sql.gz"
    incomplet=1
  fi
fi

# ── 4. Relance ───────────────────────────────────────────────────────────────
step "Relance des apps"
compose up -d
arrete=0
compose ps
printf '\n'
ok "restauration terminée"
ok "quand tout est vérifié, les données d'avant peuvent être supprimées : sudo rm -rf $ROOT/$ancien"
[ "$incomplet" -eq 0 ] || die "restauration incomplète : la base de Nexus n'a pas été rejouée"
