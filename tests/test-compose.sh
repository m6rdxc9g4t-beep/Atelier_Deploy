#!/usr/bin/env bash
# docker-compose.yml : règles que la configuration résolue doit toujours respecter (docker compose config suffit,
# pas besoin du démon). Sauté si docker compose ou python3 manquent.
source "$(dirname "$0")/banc.sh"
if ! docker compose version >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
  echo "docker compose ou python3 introuvable : test sauté"; exit 0
fi

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf '%s\n' ATELIER_DOMAIN=atelier.exemple.test ACME_EMAIL=a@exemple.test PORTAL_PASSWORD=motdepasse-de-test \
  SESSION_SECRET=0123456789abcdef0123456789abcdef POSTGRES_PASSWORD=pg APPS_SECRET_KEY=cle > "$tmp/test.env"
docker compose -f "$DEPOT/docker-compose.yml" --env-file "$tmp/test.env" config --format json > "$tmp/config.json" \
  || { echo "docker compose config échoue"; exit 1; }

# regle "<message>" "<expression Python sur s = services, vraie si la règle est respectée>"
regle() {
  if python3 - "$tmp/config.json" "$2" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))["services"]
PUBLICS = ["portfolio", "ops"]          # sites sans la connexion du portail, hors du réseau de l'hôte
sys.exit(0 if eval(sys.argv[2]) else 1)
PY
  then vert "$1"; else rouge "$1"; fi
}

titre "Réseau"
regle "aucun port n'est publié ailleurs que sur 127.0.0.1" \
  'all(p.get("host_ip") == "127.0.0.1" for v in s.values() for p in v.get("ports", []))'
regle "les sites publics (Portfolio, Ops Lab) ne partagent pas le réseau de l'hôte" \
  'all(s[n].get("network_mode") != "host" for n in PUBLICS)'
regle "ils sont sur leur propre réseau, sans PostgreSQL" \
  'all(list(s[n].get("networks", {})) == ["vitrine"] for n in PUBLICS) and "vitrine" not in s["postgres"].get("networks", {})'
regle "leurs ports restent ceux que Caddy et le portail appellent (127.0.0.1:8787 et :3400)" \
  '[(p["published"], p["target"]) for n in PUBLICS for p in s[n]["ports"]] == [("8787", 8787), ("3400", 3400)]'
regle "ils écoutent sur toutes les interfaces de leur conteneur" \
  's["portfolio"]["environment"]["HOST"] == "0.0.0.0" and s["ops"]["environment"]["HOSTNAME"] == "0.0.0.0"'
regle "ils tournent sans privilège, mémoire et processus bornés" \
  'all(s[n].get("cap_drop") == ["ALL"] and "no-new-privileges:true" in s[n].get("security_opt", []) and s[n].get("mem_limit") and s[n].get("pids_limit") for n in PUBLICS + ["datamind-demo"])'
regle "les apps privées restent sur le réseau de l'hôte (elles se parlent en 127.0.0.1)" \
  'all(v.get("network_mode") == "host" for n, v in s.items() if n not in PUBLICS + ["postgres"])'

titre "Sondes et journaux"
regle "chaque service a une sonde (update.sh l'attend avant de dire « à jour »)" \
  'all("healthcheck" in v for v in s.values())'
regle "chaque app tourne sous docker-init (arrêt propre en 1 s au lieu de 10)" \
  'all(v.get("init") is True for n, v in s.items() if n != "postgres")'
regle "chaque service redémarre seul" \
  'all(v.get("restart") == "unless-stopped" for v in s.values())'

titre "Caddy"
attendu "l'image de Caddy valide le Caddyfile à la construction (après l'avoir copié)" \
  test "$(grep -n 'caddy validate --config /etc/caddy/Caddyfile' "$DEPOT/caddy/Dockerfile" | cut -d: -f1)" -gt "$(grep -n '^COPY caddy/Caddyfile' "$DEPOT/caddy/Dockerfile" | cut -d: -f1)"

banc_fin
