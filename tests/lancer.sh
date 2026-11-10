#!/usr/bin/env bash
# Toutes les vérifications du kit, sans démon Docker ni réseau :  ./tests/lancer.sh
# À lancer avant chaque commit qui touche un script, docker-compose.yml, le Caddyfile ou le portail.
#
# Outils facultatifs (étape sautée, et signalée, s'ils manquent) :
#   docker compose   validation de docker-compose.yml (la commande suffit, pas le démon)
#   caddy            validation du Caddyfile          CADDY=/chemin/vers/caddy ./tests/lancer.sh
#   l'outil shellcheck : analyse des scripts     SHELLCHECK="uvx --from shellcheck-py shellcheck" ./tests/lancer.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SCRIPTS=(install.sh update.sh auto-update.sh backup.sh scripts/lib.sh demo/charger.sh tests/banc.sh tests/lancer.sh tests/test-*.sh)
[ -f restore.sh ] && SCRIPTS+=(restore.sh)
echecs=0
sautes=()
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

etape() { # etape "Titre" commande…
  local titre="$1"; shift
  printf '\n▸ %s\n' "$titre"
  if "$@" > "$tmp/sortie" 2>&1; then printf '  ✓ ok\n'
  else printf '  ✗ ÉCHEC\n'; sed 's/^/    /' "$tmp/sortie"; echecs=$((echecs + 1)); fi
}
saute() { printf '\n▸ %s\n  – sauté : %s\n' "$1" "$2"; sautes+=("$1"); }

syntaxe() { local f; for f in "${SCRIPTS[@]}"; do bash -n "$f" || return 1; done; }
etape "Syntaxe des scripts (bash -n)" syntaxe

read -r -a shellcheck <<<"${SHELLCHECK:-shellcheck}"
if command -v "${shellcheck[0]}" >/dev/null 2>&1; then
  etape "Analyse des scripts (shellcheck, avertissements et erreurs)" "${shellcheck[@]}" -x -S warning -e SC1091 "${SCRIPTS[@]}"
else
  saute "Analyse des scripts (shellcheck)" "shellcheck introuvable"
fi

if docker compose version >/dev/null 2>&1; then
  printf '%s\n' ATELIER_DOMAIN=atelier.exemple.test ACME_EMAIL=a@exemple.test PORTAL_PASSWORD=motdepasse-de-test \
    SESSION_SECRET=0123456789abcdef0123456789abcdef POSTGRES_PASSWORD=pg APPS_SECRET_KEY=cle > "$tmp/test.env"
  etape "docker-compose.yml (docker compose config)" docker compose --env-file "$tmp/test.env" config -q
else
  saute "docker-compose.yml (docker compose config)" "docker compose introuvable"
fi

CADDY="${CADDY:-caddy}"
if command -v "$CADDY" >/dev/null 2>&1; then
  # La même commande que caddy/Dockerfile : un Caddyfile fautif ne doit jamais arriver en service.
  etape "Caddyfile (caddy validate)" env ATELIER_DOMAIN=exemple.test ACME_EMAIL=validation@exemple.test \
    XDG_DATA_HOME="$tmp/caddy" XDG_CONFIG_HOME="$tmp/caddy" "$CADDY" validate --config caddy/Caddyfile --adapter caddyfile
else
  saute "Caddyfile (caddy validate)" "caddy introuvable (CADDY=/chemin/vers/caddy)"
fi

if command -v node >/dev/null 2>&1; then
  etape "Portail (node --check)" node --check portail/server.mjs
  if compgen -G "portail/tests/*.test.mjs" >/dev/null; then etape "Portail (node --test)" node --test portail/tests/; fi
else
  saute "Portail" "node introuvable"
fi

for essai in tests/test-*.sh; do
  etape "Banc : $essai" bash "$essai"
done

printf '\n'
if [ ${#sautes[@]} -gt 0 ]; then printf 'Étapes sautées : %s\n' "${#sautes[@]}"; fi
if [ "$echecs" -gt 0 ]; then printf '%d étape(s) en échec\n' "$echecs"; exit 1; fi
printf 'Tout est vert\n'
