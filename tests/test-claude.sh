#!/usr/bin/env bash
# Claude avec le forfait (CLAUDE_OAUTH_TOKEN) : chaque app reçoit le jeton sous le nom qu'elle lit, et elle seule ;
# jamais la clé API à sa place ; sans jeton, aucune variable ne change (la CLI reste dans les images). La CLI Claude Code est dans les images qui la lancent,
# en version épinglée. docker compose config suffit (pas besoin du démon) ; sauté si docker compose ou python3 manquent.
source "$(dirname "$0")/banc.sh"
if ! docker compose version >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
  echo "docker compose ou python3 introuvable : test sauté"; exit 0
fi

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
JETON=sk-ant-oat01-JETON-COMMUN-DE-TEST
CLE=sk-ant-api03-CLE-API-DE-TEST

# config <nom> [VAR=valeur…] : configuration résolue de docker-compose.yml avec ces réglages en plus dans .env.
config() {
  local nom="$1"; shift
  printf '%s\n' ATELIER_DOMAIN=atelier.exemple.test ACME_EMAIL=a@exemple.test PORTAL_PASSWORD=motdepasse-de-test \
    SESSION_SECRET=0123456789abcdef0123456789abcdef POSTGRES_PASSWORD=pg APPS_SECRET_KEY=cle "$@" > "$tmp/$nom.env"
  # Le jeton ne doit venir que du fichier : pas d'une variable du poste qui lance le test.
  env -u CLAUDE_OAUTH_TOKEN -u HUB_CLAUDE_OAUTH_TOKEN -u DATAMIND_CLAUDE_OAUTH_TOKEN -u ANTHROPIC_API_KEY \
    docker compose -f "$DEPOT/docker-compose.yml" --env-file "$tmp/$nom.env" config --format json > "$tmp/$nom.json" \
    || { rouge "docker compose config échoue ($nom)"; return 1; }
}

# regle <config> "<message>" "<expression Python sur s = services, e(n) = environnement du service n>"
regle() {
  if python3 - "$tmp/$1.json" "$3" "$JETON" "$CLE" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))["services"]
JETON, CLE = sys.argv[3], sys.argv[4]
def e(n): return s[n].get("environment") or {}
# Nom sous lequel chaque app lit le jeton (son code réel : claude_token.py, claude-token.ts, config de DataMind).
NOMS = {"viz": "CLAUDE_OAUTH_TOKEN", "convert": "CLAUDE_OAUTH_TOKEN", "projets": "CLAUDE_OAUTH_TOKEN",
        "nexus-backend": "CLAUDE_OAUTH_TOKEN", "hub": "HUB_CLAUDE_OAUTH_TOKEN", "datamind": "CLAUDE_CODE_OAUTH_TOKEN"}
CLI = ["viz", "convert", "projets", "nexus-backend", "hub"]   # apps qui lancent elles-mêmes la CLI isolée
def porteurs(valeur): return sorted(n for n in s if valeur in (e(n) or {}).values())
sys.exit(0 if eval(sys.argv[2]) else 1)
PY
  then vert "$2"; else rouge "$2"; fi
}

titre "Sans jeton (installation existante, .env inchangé) : aucun jeton dans l'environnement des apps"
config sans
regle sans "aucun service ne reçoit de jeton (variables vides)" \
  'all(e(n).get(v, "") == "" for n in s for v in ("CLAUDE_OAUTH_TOKEN", "HUB_CLAUDE_OAUTH_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN"))'
config cle "ANTHROPIC_API_KEY=$CLE"
regle cle "la clé API n'est jamais posée là où une app lit un jeton du forfait" \
  'all(e(n).get(v, "") == "" for n in s for v in ("CLAUDE_OAUTH_TOKEN", "HUB_CLAUDE_OAUTH_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN"))'
regle cle "elle ne va qu'aux apps qui savent s'en servir sans la passer à la CLI (Viz, Convert, Nexus, DataMind)" \
  'porteurs(CLE) == ["convert", "datamind", "nexus-backend", "viz"]'

titre "Jeton commun (CLAUDE_OAUTH_TOKEN dans .env) : chaque app le reçoit sous le nom qu'elle lit"
config commun "CLAUDE_OAUTH_TOKEN=$JETON" "ANTHROPIC_API_KEY=$CLE"
regle commun "Viz, Convert, Projets, Nexus : CLAUDE_OAUTH_TOKEN ; Hub : HUB_CLAUDE_OAUTH_TOKEN ; DataMind : CLAUDE_CODE_OAUTH_TOKEN" \
  'all(e(n).get(v) == JETON for n, v in NOMS.items())'
regle commun "et seulement elles (ni la démo publique de DataMind, ni le Wiki, ni les sites publics)" \
  'porteurs(JETON) == sorted(NOMS)'
regle commun "chacune sous un seul nom (CLAUDE_CODE_OAUTH_TOKEN, nom de la CLI, n'est posé que pour DataMind)" \
  'all(sum(1 for x in e(n).values() if x == JETON) == 1 for n in NOMS) and all("CLAUDE_CODE_OAUTH_TOKEN" not in e(n) for n in CLI)'
regle commun "jamais de clé API vers le Hub ni vers Projets (ils ne parlent à Claude que par la CLI)" \
  'all("ANTHROPIC_API_KEY" not in e(n) and CLE not in e(n).values() for n in ["hub", "projets"])'
regle commun "le Hub rédige aussi avec l'IA du serveur, en bouclage" \
  'e("hub").get("OLLAMA_URL") == "http://127.0.0.1:11434" and e("hub").get("OLLAMA_MODEL") and e("hub").get("OLLAMA_NUM_CTX") == "8192"'

titre "Jetons propres au Hub et à DataMind : prioritaires sur le commun"
config propres "CLAUDE_OAUTH_TOKEN=$JETON" HUB_CLAUDE_OAUTH_TOKEN=sk-ant-oat01-HUB DATAMIND_CLAUDE_OAUTH_TOKEN=sk-ant-oat01-DM
regle propres "le Hub et DataMind prennent le leur, les autres le commun" \
  'e("hub").get("HUB_CLAUDE_OAUTH_TOKEN") == "sk-ant-oat01-HUB" and e("datamind").get("CLAUDE_CODE_OAUTH_TOKEN") == "sk-ant-oat01-DM" and all(e(n).get("CLAUDE_OAUTH_TOKEN") == JETON for n in ["viz", "convert", "projets", "nexus-backend"])'
config seul_dm DATAMIND_CLAUDE_OAUTH_TOKEN=sk-ant-oat01-DM
regle seul_dm "le jeton propre à DataMind (réglage d'avant) ne se répand pas aux autres apps" \
  'porteurs("sk-ant-oat01-DM") == ["datamind"]'

titre "La CLI Claude Code est dans les images qui la lancent, en version épinglée"
regle sans "Viz, Convert, Projets, Hub et Nexus sont construits avec la même version, exacte (x.y.z)" \
  'len({s[n]["build"]["args"].get("CLAUDE_CODE_VERSION") for n in CLI}) == 1 and __import__("re").fullmatch(r"\d+\.\d+\.\d+", s["viz"]["build"]["args"]["CLAUDE_CODE_VERSION"])'
regle sans "les autres images ne l'embarquent pas" \
  'all("CLAUDE_CODE_VERSION" not in (v.get("build") or {}).get("args", {}) for n, v in s.items() if n not in CLI)'
declare -A chemin=([viz]=CLAUDE_CLI [convert]=CLAUDE_CLI [projets]=CLAUDE_CLI [hub]=CLAUDE_CLI [nexus-backend]=CLAUDE_CLI_PATH)
manque=0
for app in "${!chemin[@]}"; do
  f="$DEPOT/docker/$app.Dockerfile"
  grep -qF 'npm install -g --no-audit --no-fund "@anthropic-ai/claude-code@$CLAUDE_CODE_VERSION"' "$f" \
    && grep -qF -- '--version | grep -qF "$CLAUDE_CODE_VERSION"' "$f" \
    && grep -qF 'COPY --from=claude /usr/local/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe /usr/local/bin/claude' "$f" \
    && grep -qF 'RUN ["/usr/local/bin/claude", "--version"]' "$f" \
    && grep -qE "^ *${chemin[$app]}=/usr/local/bin/claude( |$)" "$f" \
    || { rouge "$app : CLI absente, non épinglée, non vérifiée ou introuvable par l'app (${chemin[$app]})"; manque=1; }
done
[ "$manque" -eq 1 ] || vert "chacune installe la version épinglée, la vérifie (--version) et dit à l'app où la trouver (Nexus : CLAUDE_CLI_PATH)"
refuse "aucune image ne lance une vraie demande à Claude à la construction (-p, --print)" \
  grep -nE 'claude(\.exe)?"?,? .*(-p( |"|$)|--print)' "$DEPOT"/docker/*.Dockerfile
attendu "Projets : migrations lancées sans le jeton, API lancée par node lui-même (aucun npm ne le garde)" \
  grep -qF 'env -u CLAUDE_OAUTH_TOKEN npm run db:deploy --workspace=@atelier/backend && cd backend && exec node dist/server.js' "$DEPOT/docker/projets.Dockerfile"

banc_fin
