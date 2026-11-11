#!/usr/bin/env bash
# tests/lancer.sh lui-même : ce qui est sauté (outil absent, banc qui se saute, tests du navigateur sans Playwright)
# doit être dit et rappelé à la fin, jamais affiché « ✓ ok » ni couvert par « Tout est vert ».
# lancer.sh est copié dans un faux kit (scripts vides, bancs de trois lignes, faux docker, faux caddy) : rien du vrai
# kit n'est relancé. Sauté si node manque.
source "$(dirname "$0")/banc.sh"
command -v node >/dev/null 2>&1 || { echo "node introuvable : test sauté"; exit 0; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
kit="$tmp/kit"
mkdir -p "$kit/tests" "$kit/scripts" "$kit/demo" "$kit/portail/tests" "$tmp/bin" "$tmp/maison"
for f in install.sh update.sh auto-update.sh backup.sh restore.sh scripts/lib.sh demo/charger.sh tests/banc.sh; do : > "$kit/$f"; done
cp "$DEPOT/tests/lancer.sh" "$kit/tests/"
: > "$kit/portail/server.mjs"
# Le même mécanisme que portail/tests/page.test.mjs : sauté si le module « playwright » est introuvable.
cat > "$kit/portail/tests/page.test.mjs" <<'EOF'
import { test } from 'node:test'
import { createRequire } from 'node:module'
let navigateur = null
try { navigateur = createRequire(import.meta.url)('playwright') } catch {}
test('dans un navigateur', { skip: navigateur ? false : 'Playwright introuvable' }, () => {})
test('sans navigateur', () => {})
EOF
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/faux-outil"
# Faux docker : « compose » connu ou non selon DOCKER_ABSENT.
printf '#!/usr/bin/env bash\n[ -z "${DOCKER_ABSENT:-}" ]\n' > "$tmp/bin/docker"
chmod +x "$tmp/bin/faux-outil" "$tmp/bin/docker"

banc_vert()    { printf '#!/usr/bin/env bash\necho "── Un cas"\necho "tout est vert"\n' > "$kit/tests/test-$1.sh"; }
banc_saute()   { printf '#!/usr/bin/env bash\necho "caddy introuvable : test sauté"; exit 0\n' > "$kit/tests/test-$1.sh"; }
banc_partiel() { printf '#!/usr/bin/env bash\necho "── Un cas"\necho "── Verrou sans droit : sauté (unshare indisponible sous root)"\n' > "$kit/tests/test-$1.sh"; }
banc_rouge()   { printf '#!/usr/bin/env bash\necho "1 vérification(s) en échec"; exit 1\n' > "$kit/tests/test-$1.sh"; }

# lancer <variables…> : lance le faux kit sans rien hériter de la machine (ni NODE_PATH, ni dossier personnel).
lancer() {
  sortie="$(env -u NODE_PATH HOME="$tmp/maison" PATH="$tmp/bin:$PATH" "$@" bash "$kit/tests/lancer.sh" 2>&1)"; code=$?
}
dit()      { if grep -qF -- "$1" <<<"$sortie"; then vert "${2:-il écrit « $1 »}"; else rouge "${2:-il écrit « $1 »} (absent de la sortie)"; fi; }
# Le message par défaut passe par une variable : une apostrophe dans "${2:-…}" ouvrirait une chaîne et avalerait le « else ».
ne_dit_pas() {
  local m="${2:-}"; [ -n "$m" ] || m="il n'écrit pas « $1 »"
  if grep -qF -- "$1" <<<"$sortie"; then rouge "$m"; else vert "$m"; fi
}
recap()    { sed -n '/^Sauté, donc non vérifié/,$p' <<<"$sortie"; }

titre "Tous les outils présents, aucun banc sauté : « Tout est vert »"
mkdir -p "$kit/portail/node_modules/playwright"; echo 'module.exports = {}' > "$kit/portail/node_modules/playwright/index.js"
banc_vert un
lancer SHELLCHECK="$tmp/bin/faux-outil" CADDY="$tmp/bin/faux-outil"
attendu "code de sortie 0" test "$code" -eq 0
attendu "dernière ligne : « Tout est vert »" test "$(tail -n1 <<<"$sortie")" = "Tout est vert"
ne_dit_pas "sauté" "rien n'est dit sauté"

titre "Sans Playwright : les tests du navigateur sont sautés, et c'est dit"
rm -rf "$kit/portail/node_modules"
if (cd "$kit/portail/tests" && env -u NODE_PATH HOME="$tmp/maison" node -e "require('playwright')") 2>/dev/null; then
  printf '\n── Sans Playwright : sauté (node trouve « playwright » même sans NODE_PATH ni dossier personnel)\n'
else
  lancer SHELLCHECK="$tmp/bin/faux-outil" CADDY="$tmp/bin/faux-outil"
  attendu "code de sortie 0 : rien n'a échoué" test "$code" -eq 0
  dit "dont 1 test(s) sauté(s) : Playwright introuvable" "l'étape du portail compte le test sauté et donne la raison"
  attendu "le rappel final le reprend" grep -q "Portail (node --test), 1 test(s) : Playwright introuvable" <<<"$(recap)"
  attendu "dernière ligne : « Le reste est vert »" test "$(tail -n1 <<<"$sortie")" = "Le reste est vert"
  ne_dit_pas "Tout est vert"
fi
mkdir -p "$kit/portail/node_modules/playwright"; echo 'module.exports = {}' > "$kit/portail/node_modules/playwright/index.js"

titre "Un banc qui se saute lui-même (caddy absent) n'est pas « ✓ ok »"
banc_saute deux
banc_partiel trois
lancer SHELLCHECK="$tmp/bin/faux-outil" CADDY="$tmp/bin/faux-outil"
attendu "code de sortie 0" test "$code" -eq 0
attendu "le banc sauté est affiché « sauté » avec sa raison, pas « ok »" \
  grep -qzP 'Banc : tests/test-deux\.sh\n  – sauté : caddy introuvable\n' <<<"$sortie"
attendu "le banc vert reste « ✓ ok »" grep -qzP 'Banc : tests/test-un\.sh\n  ✓ ok\n' <<<"$sortie"
attendu "un banc sauté en partie reste « ✓ ok », la partie sautée est dite" \
  grep -qzP 'Banc : tests/test-trois\.sh\n  ✓ ok\n  – en partie sauté : Verrou sans droit : sauté \(unshare indisponible sous root\)\n' <<<"$sortie"
attendu "le rappel final compte les deux" grep -q "^Sauté, donc non vérifié sur cette machine (2) :" <<<"$sortie"
attendu "et nomme le banc sauté" grep -q "Banc : tests/test-deux.sh : caddy introuvable" <<<"$(recap)"
attendu "et la partie sautée" grep -q "Banc : tests/test-trois.sh, en partie : Verrou sans droit" <<<"$(recap)"
attendu "dernière ligne : « Le reste est vert »" test "$(tail -n1 <<<"$sortie")" = "Le reste est vert"
ne_dit_pas "Tout est vert"

titre "Outils absents (shellcheck, docker compose, caddy) : chaque étape sautée est rappelée à la fin"
rm -f "$kit/tests/test-deux.sh" "$kit/tests/test-trois.sh"
lancer SHELLCHECK=outil-introuvable-atelier CADDY=outil-introuvable-atelier DOCKER_ABSENT=1
attendu "code de sortie 0" test "$code" -eq 0
attendu "trois étapes sautées" grep -q "^Sauté, donc non vérifié sur cette machine (3) :" <<<"$sortie"
attendu "shellcheck" grep -q "shellcheck) : shellcheck introuvable" <<<"$(recap)"
attendu "docker compose" grep -q "docker compose config) : docker compose introuvable" <<<"$(recap)"
attendu "caddy" grep -q "caddy validate) : caddy introuvable" <<<"$(recap)"
ne_dit_pas "Tout est vert"

titre "Un banc en échec : code de sortie 1, même avec des étapes sautées"
banc_rouge quatre
lancer SHELLCHECK=outil-introuvable-atelier CADDY="$tmp/bin/faux-outil"
attendu "code de sortie 1" test "$code" -eq 1
dit "1 étape(s) en échec"
dit "Sauté, donc non vérifié sur cette machine (1) :" "l'étape sautée est rappelée quand même"
ne_dit_pas "est vert" "ni « Tout est vert » ni « Le reste est vert »"

banc_fin
