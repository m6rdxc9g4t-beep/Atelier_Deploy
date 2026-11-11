#!/usr/bin/env bash
# Banc d'essai des scripts du kit (install, update, auto-update, backup, restore), sans Docker ni réseau :
# une copie fraîche du kit, un faux `docker` qui note ses appels, et les 15 dépôts des apps simulés par des dépôts
# git locaux. Rien n'est écrit hors d'un dossier temporaire ; rien n'est lancé sur la machine.
#
#   source tests/banc.sh ; banc_neuf     → $SIM (dossier du banc), $SIM/kit (copie du kit), $SIM_LOG (appels à docker)
#   publier <dépôt>                      → nouveau commit sur la branche main du dépôt simulé (ex. publier agent-ops-lab)
#   attendu "<message>" <commande…>      → la commande doit réussir     refuse "<message>" <commande…> → doit échouer
#   dans_journal "<texte>" / hors_journal "<texte>"                     → appel à docker présent / absent
#
# Réglages du faux docker (variables d'environnement) :
#   DOCKER_FAIL_ON="build ops"     fait échouer tout appel qui contient ce texte
#   DOCKER_FAIL_ONCE="build ops"   idem, une seule fois (panne passagère)
#   DOCKER_SLEEP_ON="build" DOCKER_SLEEP=2   ralentit ces appels
#   $SIM/image-retenue             tant que ce fichier existe, « rmi » de l'image qu'il nomme échoue (encore utilisée)
#   DOCKER_VERSION=24.0.7          version annoncée du moteur
#   DOCKER_SANS_INIT=1             docker info ne connaît pas docker-init
#   DOCKER_SANS_IMAGE=1            aucune image déjà construite (premier lancement)
#   PSQL_ERREUR_SQL=1              une instruction SQL échoue : comme le vrai psql, code non nul avec ON_ERROR_STOP seulement
#   PG_REEL=/chemin/bin            psql et pg_dump du service postgres sont les vrais (PGHOST et PGPORT disent où)
#   $SIM/en-marche                 services « en marche » (un par ligne) rendus par `compose ps --services`
# Réglages du faux tar : TAR_FAIL=1 (échec, comme un disque plein), TAR_SLEEP=2 (archive lente),
# ARCHIVE_ILLISIBLE_A_L_EXTRACTION=1 (toute extraction échoue).
# Faux df : DF_LIBRE_KO=1024 (espace libre annoncé, en Ko).

DEPOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPOTS_SIMULES=(Atelier_Nexus Atelier_Viz atelier-tab Atelier_Convert Agent_Data Atelier_Projets Atelier_Wiki Atelier_Hub
  Atelier_Formulaire Atelier_Cine Atelier-Savoir Atelier_Tr-sorerie Atelier_Portefolio agent-ops-lab Atelier_Mission)
echecs=0

banc_neuf() {
  [ -n "${SIM:-}" ] && [ -d "$SIM" ] && rm -rf "$SIM"
  SIM="$(mktemp -d "${TMPDIR:-/tmp}/atelier-banc.XXXXXX")"
  export SIM SIM_LOG="$SIM/docker.log"
  mkdir -p "$SIM/kit" "$SIM/bin" "$SIM/remotes/m6rdxc9g4t-beep" "$SIM/work"
  cp -r "$DEPOT"/{install.sh,update.sh,auto-update.sh,backup.sh,scripts,docker-compose.yml,.env.example,caddy,portail} "$SIM/kit/"
  [ -f "$DEPOT/restore.sh" ] && cp "$DEPOT/restore.sh" "$SIM/kit/"
  awk '/^services:/{s=1;next} /^[a-z]/{s=0} s && /^  [a-z][a-z0-9-]*:$/{sub(":","");print $1}' "$DEPOT/docker-compose.yml" > "$SIM/services"
  cp "$SIM/services" "$SIM/en-marche"

  cat > "$SIM/bin/docker" <<'FAUX'
#!/usr/bin/env bash
# Faux docker : note chaque appel, répond le strict nécessaire.
args="$*"
echo "docker $args" >> "$SIM_LOG"
if [ -n "${DOCKER_SLEEP_ON:-}" ] && [[ "$args" == *"$DOCKER_SLEEP_ON"* ]]; then sleep "${DOCKER_SLEEP:-2}"; fi
if [ -n "${DOCKER_FAIL_ON:-}" ] && [[ "$args" == *"$DOCKER_FAIL_ON"* ]]; then exit 1; fi
if [ -n "${DOCKER_FAIL_ONCE:-}" ] && [[ "$args" == *"$DOCKER_FAIL_ONCE"* ]] && [ ! -e "$SIM/panne-passee" ]; then
  : > "$SIM/panne-passee"; exit 1
fi
if [ -n "${PG_REEL:-}" ] && [[ "$args" == *"exec -T postgres p"* ]]; then
  while [ "$1" != postgres ]; do shift; done
  outil="$2"; shift 2
  exec "$PG_REEL/$outil" "$@"
fi
case "$args" in
  *"config --services"*) cat "$SIM/services" ;;
  *"config --hash "*)   # empreinte de la configuration résolue d'un service : le fichier et ses réglages de .env
    service="${args##* }"
    case "$service" in portail) motif='^(ATELIER_DOMAIN|PORTAL_|SESSION_)' ;; *) motif='^(ATELIER_DOMAIN|ACME_EMAIL)=' ;; esac
    echo "$service $({ grep -E "$motif" .env; cat docker-compose.yml; } | sha256sum | cut -d' ' -f1)" ;;
  *"ps --services"*) cat "$SIM/en-marche" ;;
  *"exec -T postgres pg_dump"*) echo "-- faux export de la base de Nexus" ;;
  *"exec -T postgres psql"*)
    cat >> "$SIM/psql.recu"
    if [ -n "${PSQL_ERREUR_SQL:-}" ] && [[ "$args" == *"ON_ERROR_STOP=1"* ]]; then echo "psql: erreur SQL simulée" >&2; exit 3; fi ;;
  "info --format"*) if [ -n "${DOCKER_SANS_INIT:-}" ]; then echo "N/A"; else echo "de40ad0"; fi ;;
  "version --format"*) echo "${DOCKER_VERSION:-29.0.0}" ;;
  "rmi "*)   # une image encore utilisée par un conteneur ne se supprime pas
    if [ -e "$SIM/image-retenue" ] && [[ "$args" == *"$(cat "$SIM/image-retenue")"* ]]; then exit 1; fi ;;
  *"up -d --wait --wait-timeout 300 datamind-demo"*) rm -f "$SIM/image-retenue" ;;   # la démo passe sur la nouvelle image
  "image inspect"*) [ -z "${DOCKER_SANS_IMAGE:-}" ] || exit 1 ;;
esac
exit 0
FAUX
  cat > "$SIM/bin/tar" <<'FAUX'
#!/usr/bin/env bash
# Faux tar : le vrai, sauf panne ou lenteur demandée pour la création d'une archive (-c).
vrai=/usr/bin/tar; [ -x "$vrai" ] || vrai=/bin/tar
if [[ "$1" == -x* ]] && [ -n "${ARCHIVE_ILLISIBLE_A_L_EXTRACTION:-}" ]; then echo "tar: erreur de lecture simulée" >&2; exit 2; fi
if [[ "$1" == -c* ]]; then
  [ -z "${TAR_SLEEP:-}" ] || sleep "$TAR_SLEEP"
  if [ -n "${TAR_FAIL:-}" ]; then : > "$2"; echo "tar: écriture impossible (disque plein simulé)" >&2; exit 2; fi
fi
exec "$vrai" "$@"
FAUX
  cat > "$SIM/bin/df" <<'FAUX'
#!/usr/bin/env bash
# Faux df : le vrai, sauf espace libre imposé.
if [ -n "${DF_LIBRE_KO:-}" ]; then printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/sim 41152736 0 %s 0%% /\n' "$DF_LIBRE_KO"; exit 0; fi
vrai=/usr/bin/df; [ -x "$vrai" ] || vrai=/bin/df
exec "$vrai" "$@"
FAUX
  # Hors root (poste de développement, CI), chown échouerait : ensure_dirs n'a pas à réussir pour de vrai ici.
  if [ "$(id -u)" -ne 0 ]; then printf '#!/usr/bin/env bash\nexit 0\n' > "$SIM/bin/chown"; fi
  chmod +x "$SIM/bin/"*

  cat > "$SIM/gitconfig" <<CONF
[url "file://$SIM/remotes/"]
	insteadOf = https://github.com/
[user]
	name = banc
	email = banc@exemple.test
[init]
	defaultBranch = main
[protocol "file"]
	allow = always
[commit]
	gpgsign = false
CONF
  export GIT_CONFIG_GLOBAL="$SIM/gitconfig" GIT_CONFIG_NOSYSTEM=1 PATH="$SIM/bin:$PATH"
  # Le kit simulé n'est pas un dépôt git : update.sh ne cherche pas à se mettre à jour lui-même.
  export ATELIER_KIT_A_JOUR=1 ATELIER_VERROU_FICHIER="$SIM/atelier.lock"
  unset ATELIER_VERROU DOCKER_FAIL_ON DOCKER_FAIL_ONCE DOCKER_SLEEP_ON DOCKER_SLEEP DOCKER_SANS_IMAGE DOCKER_SANS_INIT DOCKER_VERSION ATELIER_DOCKER_INIT TAR_FAIL TAR_SLEEP DF_LIBRE_KO ARCHIVE_ILLISIBLE_A_L_EXTRACTION PSQL_ERREUR_SQL PG_REEL
  local repo
  for repo in "${DEPOTS_SIMULES[@]}"; do
    git init -q --bare "$SIM/remotes/m6rdxc9g4t-beep/$repo.git"
    git clone -q "$SIM/remotes/m6rdxc9g4t-beep/$repo.git" "$SIM/work/$repo" 2>/dev/null
    (cd "$SIM/work/$repo" && echo "$repo 1" > VERSION && git add . && git commit -qm v1 && git push -q origin HEAD:main)
  done
  printf '%s\n' ATELIER_DOMAIN=atelier.exemple.test ACME_EMAIL=a@exemple.test PORTAL_PASSWORD=motdepasse-de-test \
    OLLAMA_MODEL=llama3.2:1b "AUTO_UPDATE_APPS=ops portfolio" > "$SIM/kit/.env"
  : > "$SIM_LOG"
  cd "$SIM/kit" || return 1
}

banc_fin() {
  cd "$DEPOT" || true
  [ -n "${SIM:-}" ] && rm -rf "$SIM"
  if [ "$echecs" -gt 0 ]; then printf '\n%d vérification(s) en échec\n' "$echecs"; exit 1; fi
  printf '\ntout est vert\n'
}

publier() { (cd "$SIM/work/$1" && echo "$1 $(date +%s%N)" > VERSION && git commit -qam "maj" && git push -q origin HEAD:main); }
vider_journal() { : > "$SIM_LOG"; }

titre() { printf '\n── %s\n' "$*"; }
vert()  { printf '  ✓ %s\n' "$*"; }
rouge() { printf '  ✗ %s\n' "$*"; echecs=$((echecs + 1)); }

attendu() { local m="$1"; shift; if "$@" >/dev/null 2>&1; then vert "$m"; else rouge "$m"; fi; }
refuse()  { local m="$1"; shift; if "$@" >/dev/null 2>&1; then rouge "$m"; else vert "$m"; fi; }
dans_journal() { if grep -qF -- "$1" "$SIM_LOG"; then vert "${2:-docker $1}"; else rouge "${2:-docker $1} (absent du journal)"; fi; }
hors_journal() { if grep -qF -- "$1" "$SIM_LOG"; then rouge "${2:-pas de docker $1} (présent dans le journal)"; else vert "${2:-pas de docker $1}"; fi; }
compte_journal() { grep -cF -- "$1" "$SIM_LOG" || true; }
