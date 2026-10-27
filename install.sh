#!/usr/bin/env bash
# Installation de la suite Atelier sur un VPS Ubuntu/Debian neuf (OVH ou autre).
# Usage :  sudo ./install.sh
# Relançable sans risque : ce qui est déjà en place est conservé.
set -euo pipefail
source "$(dirname "$0")/scripts/lib.sh"

[ "$(id -u)" -eq 0 ] || die "Lance ce script avec sudo : sudo ./install.sh"
command -v apt-get >/dev/null || die "Ce script vise Ubuntu ou Debian (apt-get introuvable)."

# ── 1. Paquets et Docker ─────────────────────────────────────────────────────
step "Paquets système"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git curl ca-certificates openssl dnsutils >/dev/null
ok "git, curl, openssl, dig"

if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
  step "Installation de Docker"
  curl -fsSL https://get.docker.com | sh >/dev/null
  systemctl enable --now docker >/dev/null
fi
ok "$(docker --version | cut -d, -f1) · $(docker compose version --short)"

# ── 2. Mémoire d'échange (les builds Next.js/Vite sont gourmands) ───────────
ram_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
if [ "$ram_mb" -lt 6000 ] && ! swapon --show | grep -q .; then
  step "Ajout de 4 Go de swap (RAM : ${ram_mb} Mo)"
  fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  ok "swap active"
fi

# ── 3. Pare-feu ──────────────────────────────────────────────────────────────
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  step "Pare-feu (ufw)"
  ufw allow OpenSSH >/dev/null; ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null; ufw allow 443/udp >/dev/null
  ok "ports 22, 80 et 443 ouverts"
fi

# ── 4. Réglages (.env) ───────────────────────────────────────────────────────
step "Réglages"
[ -f .env ] || { cp .env.example .env; ok ".env créé à partir de .env.example"; }
chmod 600 .env

ask() { # ask CLE "Question" [secret]
  local cur; cur="$(env_get "$1")"
  if [ -z "$cur" ] || [[ "$cur" == *mondomaine.fr* ]]; then
    local v=""
    if [ -t 0 ]; then
      if [ "${3:-}" = secret ]; then read -rsp "  $2 : " v; echo; else read -rp "  $2 : " v; fi
    fi
    if [ -n "$v" ]; then env_set "$1" "$v"; fi
  fi
  return 0
}
ask ATELIER_DOMAIN "Domaine du portail (ex. atelier.mondomaine.fr)"
ask ACME_EMAIL "E-mail pour les certificats HTTPS"
ask GITHUB_CLONE_TOKEN "Jeton GitHub (lecture des dépôts privés)" secret
ask ANTHROPIC_API_KEY "Clé API Anthropic (Entrée pour passer)" secret

for key in PORTAL_PASSWORD; do
  [ -n "$(env_get $key)" ] || { env_set $key "$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-20)"; ok "$key généré"; }
done
ensure_secrets
ensure_ia

DOMAIN="$(env_get ATELIER_DOMAIN)"
[ -n "$DOMAIN" ] && [[ "$DOMAIN" != *mondomaine.fr* ]] || die "Renseigne ATELIER_DOMAIN dans .env puis relance."

# ── 5. DNS ───────────────────────────────────────────────────────────────────
step "Vérification du DNS"
ip=$(curl -4 -fsS --max-time 5 https://api.ipify.org || true)
dns_ok=1
for host in "$DOMAIN" nexus."$DOMAIN" viz."$DOMAIN" tab."$DOMAIN" convert."$DOMAIN" projets."$DOMAIN" \
            tresorerie."$DOMAIN" savoir."$DOMAIN" cine."$DOMAIN" dates."$DOMAIN" suivi."$DOMAIN"; do
  got=$(dig +short A "$host" | tail -n1)
  if [ -n "$ip" ] && [ "$got" = "$ip" ]; then ok "$host → $got"
  else warn "$host → ${got:-aucune adresse} (attendu : ${ip:-IP du VPS})"; dns_ok=0; fi
done
[ "$dns_ok" -eq 1 ] || warn "Tant que le DNS ne pointe pas vers ce VPS, les certificats HTTPS ne pourront pas être émis. Caddy réessaiera tout seul."

# ── 6. Code des apps ─────────────────────────────────────────────────────────
step "Récupération des apps"
sync_apps
ensure_dirs

# ── 7. Construction et lancement ─────────────────────────────────────────────
step "Construction des images (10 à 20 minutes la première fois)"
compose build
step "Démarrage"
compose up -d --remove-orphans
ok "conteneurs lancés"
pull_model

cat <<EOF

${bold}${green}La suite Atelier est en ligne.${reset}

  Portail   https://$DOMAIN
  Identifiant  $(env_get PORTAL_USER)
  Mot de passe $(env_get PORTAL_PASSWORD)

  ${dim}Les certificats HTTPS sont demandés au premier accès (quelques secondes).
  État :        docker compose ps
  Journaux :    docker compose logs -f caddy   (ou viz, projets, nexus-backend…)
  Mise à jour : sudo ./update.sh
  Sauvegarde :  sudo ./backup.sh${reset}
EOF
