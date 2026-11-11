#!/usr/bin/env bash
# Caddy et le portail ensemble, pour de vrai mais en local : le vrai Caddyfile (en http, sur un port libre), le vrai
# portail, et un serveur témoin à la place de toutes les apps, qui répond ce qu'il a reçu (cookies, utilisateur).
# Vérifie la connexion unique de bout en bout et ce que chaque site reçoit du cookie de session.
# Sauté si caddy, node ou curl manquent :  CADDY=/chemin/vers/caddy ./tests/test-caddy.sh
source "$(dirname "$0")/banc.sh"
CADDY="${CADDY:-caddy}"
for outil in "$CADDY" node curl; do
  command -v "$outil" >/dev/null 2>&1 || { echo "$outil introuvable : test sauté"; exit 0; }
done

tmp="$(mktemp -d)"
pids=()
# shellcheck disable=SC2317  # appelée par le trap
menage() { local p; for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; rm -rf "$tmp"; }
trap menage EXIT

# Trois ports libres : Caddy, le portail, le témoin.
read -r P_CADDY P_PORTAIL P_TEMOIN < <(node -e '
  const net = require("node:net"); const s = [0, 1, 2].map(() => net.createServer().listen(0, "127.0.0.1"));
  setTimeout(() => { console.log(s.map((x) => x.address().port).join(" ")); s.forEach((x) => x.close()) }, 50)')

cat > "$tmp/temoin.mjs" <<'EOF'
import { createServer } from 'node:http'
createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' })
  res.end(`temoin=oui\ncookie=<${req.headers.cookie ?? ''}>\nutilisateur=<${req.headers['x-atelier-user'] ?? ''}>\n`)
}).listen(Number(process.argv[2]), '127.0.0.1')
EOF
node "$tmp/temoin.mjs" "$P_TEMOIN" & pids+=($!)

ATELIER_DOMAIN=atelier.localhost SITE_SCHEME=http PORTAL_PORT="$P_PORTAIL" PORTAL_USER=francois \
  PORTAL_PASSWORD=motdepasse-de-test SESSION_SECRET=0123456789abcdef0123456789abcdef \
  node "$DEPOT/portail/server.mjs" > "$tmp/portail.log" 2>&1 & pids+=($!)

# Le Caddyfile du dépôt, à trois détails près : le portail et les apps sont sur les ports du test, et l'API
# d'administration est coupée (sur le VPS, le port 2019 est celui du Caddy en service).
sed -E -e "s/127\.0\.0\.1:9000/127.0.0.1:@PORTAIL@/g" -e "s/127\.0\.0\.1:[0-9]+/127.0.0.1:$P_TEMOIN/g" \
  -e "s/127\.0\.0\.1:@PORTAIL@/127.0.0.1:$P_PORTAIL/g" -e 's/^([[:space:]]*)email \{\$ACME_EMAIL\}/&\n\1admin off/' \
  "$DEPOT/caddy/Caddyfile" > "$tmp/Caddyfile"
grep -q "admin off" "$tmp/Caddyfile" && grep -q "127.0.0.1:$P_PORTAIL" "$tmp/Caddyfile" \
  || { echo "le Caddyfile n'a pas pu être adapté au test"; exit 1; }
ATELIER_DOMAIN="atelier.localhost:$P_CADDY" SITE_SCHEME="http://" ACME_EMAIL=test@exemple.test \
  XDG_DATA_HOME="$tmp/xdg" XDG_CONFIG_HOME="$tmp/xdg" \
  "$CADDY" run --config "$tmp/Caddyfile" --adapter caddyfile > "$tmp/caddy.log" 2>&1 & pids+=($!)

# va <sous-domaine ou ""> <chemin> [options de curl…] → la réponse (en-têtes compris) dans $tmp/reponse
va() {
  local hote="${1:+$1.}atelier.localhost" chemin="$2"; shift 2
  curl -s -i --max-time 10 -H "Host: $hote" "$@" "http://127.0.0.1:$P_CADDY$chemin" > "$tmp/reponse" 2>/dev/null
}
code() { sed -n '1s/^HTTP[^ ]* \([0-9]*\).*/\1/p' "$tmp/reponse"; }
recu() { sed -n "s/^$1=<\(.*\)>.*/\1/p" "$tmp/reponse" | tr -d '\r'; }

pret=""
for _ in $(seq 1 100); do
  if va "" /sante && [ "$(code)" = 200 ] && va portfolio / && grep -q "temoin=oui" "$tmp/reponse"; then pret=1; break; fi
  sleep 0.2
done
[ -n "$pret" ] || { echo "Caddy, le portail ou le témoin ne démarrent pas"; tail -n 20 "$tmp/caddy.log" "$tmp/portail.log"; exit 1; }

titre "Connexion unique"
va "" /connexion -H "Content-Type: application/x-www-form-urlencoded" -H "Origin: http://atelier.localhost" \
  --data "utilisateur=francois&mot_de_passe=motdepasse-de-test"
SESSION="$(sed -n 's/^[Ss]et-[Cc]ookie: \(atelier_session=[^;]*\).*/\1/p' "$tmp/reponse")"
attendu "le portail ouvre une session à travers Caddy" test -n "$SESSION"
va viz / -H "Accept: text/html"
attendu "sans session, une app privée renvoie vers la connexion" grep -qi "^location: .*/connexion?retour=" "$tmp/reponse"
va viz /api/donnees -H "Accept: application/json"
attendu "et ses appels d'API reçoivent 401" test "$(code)" = 401
va viz / -H "Accept: text/html" -H "X-Atelier-User: pirate"
refuse "un en-tête X-Atelier-User inventé n'ouvre rien" grep -q "temoin=oui" "$tmp/reponse"
va viz / -H "Accept: text/html" -H "Cookie: $SESSION" -H "X-Atelier-User: pirate"
attendu "avec la session, l'app répond" grep -q "temoin=oui" "$tmp/reponse"
attendu "et reçoit l'utilisateur vérifié par le portail, pas celui du visiteur" test "$(recu utilisateur)" = francois
va viz /api/health
attendu "la sonde /api/health d'une app reste publique" grep -q "temoin=oui" "$tmp/reponse"

titre "Cookie de session et sites publics"
# Tout sous-domaine du Caddyfile qui répond sans connexion est un site public : il ne doit jamais recevoir le cookie
# de session. Un nouveau bloc public sans « import sans_session » fait donc échouer ce test.
publics=()
while read -r sous; do
  va "$sous" / -H "Accept: text/html"
  grep -q "temoin=oui" "$tmp/reponse" && publics+=("$sous")
done < <(sed -n 's/^{\$SITE_SCHEME}\([a-z0-9-]*\)\.{\$ATELIER_DOMAIN}.*/\1/p' "$DEPOT/caddy/Caddyfile")
attendu "le Portfolio, Ops Lab et la démo de DataMind sont bien vus comme publics (${publics[*]})" \
  test "$(printf '%s\n' "${publics[@]}" | sort | tr '\n' ' ')" = "demo-datamind ops portfolio "
for sous in "${publics[@]}"; do
  va "$sous" / -H "Cookie: atelier_theme=dark; $SESSION; autre=1"
  attendu "$sous ne reçoit pas le cookie de session (au milieu des autres)" test "$(recu cookie)" = "atelier_theme=dark; autre=1"
  va "$sous" / -H "Cookie: $SESSION; autre=1"
  attendu "$sous : ni en tête" test "$(recu cookie)" = "autre=1"
  va "$sous" / -H "Cookie: autre=1; $SESSION"
  refuse "$sous : ni en queue" grep -q "atelier_session" "$tmp/reponse"
  va "$sous" /api/health -H "Cookie: $SESSION"
  refuse "$sous : ni sur sa sonde" grep -q "atelier_session" "$tmp/reponse"
done

banc_fin
