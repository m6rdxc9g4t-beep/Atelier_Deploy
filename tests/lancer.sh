#!/usr/bin/env bash
# Toutes les vérifications du kit, sans démon Docker ni réseau :  ./tests/lancer.sh
# À lancer avant chaque commit qui touche un script, docker-compose.yml, le Caddyfile ou le portail.
#
# Outils facultatifs : s'ils manquent, l'étape est sautée, signalée sur place et rappelée à la fin, où le script ne
# dit plus « Tout est vert » mais ce qui n'a pas été vérifié (le code de sortie reste 0 : rien n'a échoué).
#   docker compose   validation de docker-compose.yml (la commande suffit, pas le démon), tests/test-compose.sh (+ python3)
#   caddy            validation du Caddyfile, connexion unique de bout en bout (tests/test-caddy.sh, + curl)
#                    CADDY=/chemin/vers/caddy ./tests/lancer.sh
#   l'outil shellcheck : analyse des scripts     SHELLCHECK="uvx --from shellcheck-py shellcheck" ./tests/lancer.sh
#   Playwright       la page du portail dans un vrai navigateur (portail/tests/page.test.mjs : focus au clavier,
#                    annonces aux lecteurs d'écran, cibles de 40 px et champs de 16 px au téléphone). Aucun paquet n'est
#                    ajouté au dépôt : le module « playwright » doit être visible de node (npm i -g playwright, NODE_PATH).
#   PostgreSQL       restauration de la base de Nexus rejouée pour de vrai (tests/test-restore-postgres.sh)
#   root             tests/test-install.sh (install.sh exige root, comme sur le VPS)
#
# Un banc (tests/test-*.sh) qui ne peut pas tourner ici l'écrit sur une ligne « <raison> : test sauté » et sort en 0 ;
# une partie seulement : « ── <cas> : sauté (<raison>) ». Les deux sont relevés ici, jamais comptés comme verts.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SCRIPTS=(install.sh update.sh auto-update.sh backup.sh scripts/lib.sh demo/charger.sh tests/banc.sh tests/lancer.sh tests/test-*.sh)
[ -f restore.sh ] && SCRIPTS+=(restore.sh)
echecs=0
sautes=()
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

etape() { # etape "Titre" commande…
  local titre="$1" raison; shift
  printf '\n▸ %s\n' "$titre"
  if ! "$@" > "$tmp/sortie" 2>&1; then
    printf '  ✗ ÉCHEC\n'; sed 's/^/    /' "$tmp/sortie"; echecs=$((echecs + 1)); return
  fi
  # Sortir en 0 ne suffit pas pour être vert : un banc qui s'est sauté lui-même (outil absent, pas root) n'a rien vérifié.
  if raison="$(grep -m1 ': test sauté$' "$tmp/sortie")"; then
    raison="${raison% : test sauté}"
    printf '  – sauté : %s\n' "$raison"; sautes+=("$titre : $raison"); return
  fi
  printf '  ✓ ok\n'
  while IFS= read -r raison; do
    raison="${raison#── }"
    printf '  – en partie sauté : %s\n' "$raison"; sautes+=("$titre, en partie : $raison")
  done < <(grep '^── .* : sauté (' "$tmp/sortie")
}
saute() { printf '\n▸ %s\n  – sauté : %s\n' "$1" "$2"; sautes+=("$1 : $2"); }
# Après une étape « node --test » verte : les tests que node a sautés (sans Playwright, tous ceux du navigateur).
tests_node_sautes() {
  local n raison
  n="$(grep -Eo 'skipped [0-9]+' "$tmp/sortie" | tail -n1)"; n="${n#skipped }"
  [ "${n:-0}" -gt 0 ] || return 0
  raison="$(sed -n 's/.*# SKIP //p' "$tmp/sortie" | sort -u | paste -sd ';' - | sed 's/;/ ; /g')"
  printf '  – dont %s test(s) sauté(s) : %s\n' "$n" "${raison:-voir node --test portail/tests/*.test.mjs}"
  sautes+=("Portail (node --test), $n test(s) : ${raison:-raison dans la sortie de node --test}")
}

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
  if compgen -G "portail/tests/*.test.mjs" >/dev/null; then
    avant=$echecs
    # Format TAP imposé : le compte et la raison des tests sautés se lisent de la même façon avec tout node.
    etape "Portail (node --test)" node --test --test-reporter=tap portail/tests/*.test.mjs
    [ "$echecs" -eq "$avant" ] && tests_node_sautes
  fi
else
  saute "Portail" "node introuvable"
fi

for essai in tests/test-*.sh; do
  etape "Banc : $essai" bash "$essai"
done

printf '\n'
if [ ${#sautes[@]} -gt 0 ]; then
  printf 'Sauté, donc non vérifié sur cette machine (%s) :\n' "${#sautes[@]}"
  printf '  – %s\n' "${sautes[@]}"
fi
if [ "$echecs" -gt 0 ]; then printf '%d étape(s) en échec\n' "$echecs"; exit 1; fi
if [ ${#sautes[@]} -gt 0 ]; then printf 'Le reste est vert\n'; else printf 'Tout est vert\n'; fi
