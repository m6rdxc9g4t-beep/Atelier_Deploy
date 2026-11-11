#!/usr/bin/env bash
# restore.sh face à un vrai PostgreSQL. Le banc simule psql ; or c'est le comportement du vrai (code de sortie,
# transaction, objets liés entre eux) qui décide si une base est bien remplacée et si un rejeu raté est vu.
# Facultatif : sauté si PostgreSQL n'est pas installé sur la machine (initdb, pg_ctl, psql, pg_dump ; PG_BIN=/chemin/bin
# pour un autre emplacement). Le serveur d'essai vit dans le dossier temporaire du banc, n'écoute que sur 127.0.0.1 et
# est arrêté à la fin ; rien n'est installé.
source "$(dirname "$0")/banc.sh"

if [ -z "${PG_BIN:-}" ]; then
  PG_BIN="$(command -v initdb 2>/dev/null || find /usr/lib/postgresql -name initdb -path '*/bin/*' 2>/dev/null | sort -V | tail -n1)"
  PG_BIN="${PG_BIN%/initdb}"
fi
for outil in initdb pg_ctl psql pg_dump; do
  [ -x "$PG_BIN/$outil" ] || { echo "PostgreSQL introuvable ($outil) : test sauté"; exit 0; }
done
# Le serveur refuse de tourner sous root : il est alors lancé sous un autre identifiant, dans un espace de noms.
serveur() { "$@"; }
if [ "$(id -u)" -eq 0 ]; then
  unshare -U --map-user=1000 --map-group=1000 true 2>/dev/null || { echo "PostgreSQL ne se lance pas sous root (unshare indisponible) : test sauté"; exit 0; }
  serveur() { unshare -U --map-user=1000 --map-group=1000 "$@"; }
fi

sql() { "$PG_BIN/psql" -X -q -At -v ON_ERROR_STOP=1 -U nexus -d atelier_nexus -c "$1"; }
derniere_archive() { find backups -name 'atelier-*.tar.gz' -printf '%T@ %p\n' | sort -n | tail -n1 | cut -d' ' -f2; }

PG_DOSSIER=""
arreter_pg() {
  [ -n "$PG_DOSSIER" ] && [ -f "$PG_DOSSIER/postmaster.pid" ] || return 0
  serveur "$PG_BIN/pg_ctl" -D "$PG_DOSSIER" -m immediate -w stop >/dev/null 2>&1 || true
}
trap arreter_pg EXIT

# Un banc neuf et son PostgreSQL : utilisateur nexus, base atelier_nexus, comme le service postgres du kit.
demarrer_pg() {
  arreter_pg
  banc_neuf
  PG_DOSSIER="$SIM/pg"
  serveur "$PG_BIN/initdb" -D "$PG_DOSSIER" -U nexus --auth=trust -E UTF8 >/dev/null 2>&1 || return 1
  for _ in 1 2 3 4 5; do
    PGPORT=$((20000 + RANDOM % 30000))
    if serveur "$PG_BIN/pg_ctl" -D "$PG_DOSSIER" -l "$SIM/pg.log" -w -t 60 \
         -o "-c listen_addresses=127.0.0.1 -c unix_socket_directories= -c fsync=off -p $PGPORT" start >/dev/null 2>&1; then
      export PG_REEL="$PG_BIN" PGHOST=127.0.0.1 PGPORT
      "$PG_BIN/psql" -X -q -U nexus -d postgres -c "CREATE DATABASE atelier_nexus" || return 1
      mkdir -p data/viz && echo "rapport" > data/viz/rapport.json
      return 0
    fi
  done
  return 1
}

# La base au moment de la sauvegarde : deux tables liées, et une extension dont un type sert à une colonne
# (comme vector pour Nexus) quand la machine en propose une.
remplir() {
  type_nom=text
  if [ "$(sql "SELECT count(*) FROM pg_available_extensions WHERE name = 'citext'")" = 1 ]; then
    sql "CREATE EXTENSION citext" && type_nom=citext
  fi
  sql "CREATE TABLE agents (id int PRIMARY KEY, nom $type_nom NOT NULL);
       CREATE TABLE conversations (id int PRIMARY KEY, agent_id int NOT NULL REFERENCES agents(id), titre text);
       INSERT INTO agents VALUES (1, 'Analyste'), (2, 'Rédacteur');
       INSERT INTO conversations VALUES (10, 1, 'Ventes'), (11, 2, 'Courrier');"
}
# Depuis la sauvegarde : Nexus a été mis à jour (nouvelle table liée aux anciennes) et la base a vécu.
vivre() {
  sql "CREATE TABLE memoires (id int PRIMARY KEY, agent_id int NOT NULL REFERENCES agents(id), texte text);
       INSERT INTO memoires VALUES (1, 1, 'récent');
       UPDATE agents SET nom = 'Modifié' WHERE id = 1;
       INSERT INTO conversations VALUES (99, 2, 'Récente');"
}

titre "Une base qui a changé depuis la sauvegarde (table ajoutée par une mise à jour de Nexus)"
demarrer_pg || { echo "PostgreSQL ne démarre pas ici : test sauté"; sed 's/^/    /' "$SIM/pg.log" 2>/dev/null | tail -n 5; rm -rf "$SIM"; exit 0; }
attendu "base de départ" remplir
attendu "backup.sh réussit (vrai pg_dump)" ./backup.sh
archive="$(derniere_archive)"
attendu "la base change depuis" vivre
attendu "restore.sh réussit" ./restore.sh --oui "$archive"
attendu "une ligne modifiée retrouve son contenu" test "$(sql "SELECT nom FROM agents WHERE id = 1")" = "Analyste"
attendu "une ligne ajoutée depuis n'est plus là" test "$(sql "SELECT count(*) FROM conversations")" = 2
attendu "la table apparue depuis a disparu" test "$(sql "SELECT to_regclass('public.memoires') IS NULL")" = t
attendu "le type de la colonne est celui de la sauvegarde" test "$(sql "SELECT format_type(atttypid, atttypmod) FROM pg_attribute WHERE attrelid = 'agents'::regclass AND attname = 'nom'")" = "$type_nom"
refuse "les clés étrangères sont de retour" sql "INSERT INTO conversations VALUES (100, 999, 'sans agent')"
attendu "les clés primaires aussi" test "$(sql "SELECT count(*) FROM pg_constraint WHERE contype = 'p' AND connamespace = 'public'::regnamespace")" = 2

titre "Une base déjà restaurée se sauvegarde et se restaure de nouveau"
sleep 1   # deux archives de la même seconde porteraient le même nom
attendu "backup.sh réussit" ./backup.sh
archive2="$(derniere_archive)"
refuse "c'est une nouvelle archive" test "$archive2" = "$archive"
attendu "la base change depuis" vivre
attendu "restore.sh réussit" ./restore.sh --oui "$archive2"
attendu "la base est celle de la sauvegarde" test "$(sql "SELECT count(*) FROM conversations")$(sql "SELECT to_regclass('public.memoires') IS NULL")" = 2t

titre "Un export qui ne se rejoue pas jusqu'au bout : la base reste telle qu'elle était"
mkdir "$SIM/fautif"
tar -xzf "$archive" -C "$SIM/fautif"
{ gunzip -c "$SIM/fautif/nexus.sql.gz"; echo "INSERT INTO table_inconnue VALUES (1);"; } | gzip > "$SIM/fautif/fautif.sql.gz"
mv "$SIM/fautif/fautif.sql.gz" "$SIM/fautif/nexus.sql.gz"
tar -czf backups/atelier-fautive.tar.gz -C "$SIM/fautif" data .env nexus.sql.gz
attendu "la base change depuis" vivre
sortie="$(./restore.sh --oui backups/atelier-fautive.tar.gz 2>&1)"; code=$?
attendu "restore.sh sort en erreur" test "$code" -ne 0
refuse "la base n'est pas dite rejouée" grep -q "base rejouée" <<<"$sortie"
attendu "le message dit que la restauration est incomplète" grep -q "restauration incomplète" <<<"$sortie"
attendu "aucune ligne n'a changé" test "$(sql "SELECT nom FROM agents WHERE id = 1")/$(sql "SELECT count(*) FROM conversations")" = "Modifié/3"
attendu "la table apparue depuis est toujours là, avec ses lignes" test "$(sql "SELECT count(*) FROM memoires")" = 1

arreter_pg
banc_fin
