#!/usr/bin/env bash
# Fonctions communes à install.sh, update.sh, auto-update.sh, backup.sh et restore.sh.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# Couleurs seulement dans un terminal : les journaux (cron) restent lisibles.
# shellcheck disable=SC2034  # dim sert au récapitulatif d'install.sh
if [ -t 1 ]; then
  bold=$'\e[1m'; dim=$'\e[2m'; red=$'\e[31m'; green=$'\e[32m'; yellow=$'\e[33m'; reset=$'\e[0m'
else
  bold=''; dim=''; red=''; green=''; yellow=''; reset=''
fi
step() { printf '\n%s▸ %s%s\n' "$bold" "$*" "$reset"; }
ok()   { printf '  %s✓%s %s\n' "$green" "$reset" "$*"; }
warn() { printf '  %s!%s %s\n' "$yellow" "$reset" "$*"; }
die()  { printf '\n%s✗ %s%s\n' "$red" "$*" "$reset" >&2; exit 1; }

# Lit une valeur de .env (sans exécuter le fichier).
env_get() {
  [ -f .env ] || return 0
  { grep -E "^$1=" .env || true; } | tail -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//'
}

# Écrit ou remplace une valeur dans .env.
env_set() {
  local key="$1" value="$2"
  if grep -qE "^$key=" .env; then
    local esc; esc=$(printf '%s' "$value" | sed -e 's/[\/&|]/\\&/g')
    sed -i "s|^$key=.*|$key=$esc|" .env
  else
    printf '%s=%s\n' "$key" "$value" >> .env
  fi
}

# dossier local | dépôt GitHub | variable de branche
APPS=(
  "atelier_nexus|Atelier_Nexus|BRANCH_NEXUS"
  "atelier_viz|Atelier_Viz|BRANCH_VIZ"
  "atelier-tab|atelier-tab|BRANCH_TAB"
  "atelier_convert|Atelier_Convert|BRANCH_CONVERT"
  "agent_data|Agent_Data|BRANCH_DATAMIND"
  "atelier_projets|Atelier_Projets|BRANCH_PROJETS"
  "atelier_wiki|Atelier_Wiki|BRANCH_WIKI"
  "atelier_hub|Atelier_Hub|BRANCH_HUB"
  "atelier_formulaire|Atelier_Formulaire|BRANCH_FORMULAIRE"
  "atelier_cine|Atelier_Cine|BRANCH_CINE"
  "atelier-savoir|Atelier-Savoir|BRANCH_SAVOIR"
  "atelier_tr-sorerie|Atelier_Tr-sorerie|BRANCH_TRESORERIE"
  "atelier_portefolio|Atelier_Portefolio|BRANCH_PORTFOLIO"
  # Sites & tests
  "agent-ops-lab|agent-ops-lab|BRANCH_OPS"
  "atelier_mission|Atelier_Mission|BRANCH_MISSION"
)

# Le jeton n'est jamais écrit dans .git/config : il passe par un en-tête HTTP, le temps de la commande.
git_auth() {
  local token; token="$(env_get GITHUB_CLONE_TOKEN)"
  if [ -n "$token" ]; then
    local basic; basic=$(printf 'x-access-token:%s' "$token" | base64 -w0)
    git -c credential.helper= -c "http.https://github.com/.extraheader=AUTHORIZATION: basic $basic" "$@"
  else
    git "$@"
  fi
}

sync_apps() {
  local owner; owner="$(env_get GITHUB_OWNER)"; owner="${owner:-m6rdxc9g4t-beep}"
  mkdir -p apps
  for entry in "${APPS[@]}"; do
    IFS='|' read -r dir repo branch_var <<<"$entry"
    local branch; branch="$(env_get "$branch_var")"; branch="${branch:-main}"
    if [ -d "apps/$dir/.git" ]; then
      git_auth -C "apps/$dir" fetch --depth 1 origin "$branch" -q || die "Impossible de mettre à jour $repo"
      git -C "apps/$dir" checkout -q -B "$branch" FETCH_HEAD
      git -C "apps/$dir" reset -q --hard FETCH_HEAD
    else
      git_auth clone -q --depth 1 --branch "$branch" "https://github.com/$owner/$repo.git" "apps/$dir" \
        || die "Impossible de cloner $owner/$repo (branche $branch). Vérifie GITHUB_CLONE_TOKEN dans .env."
    fi
    ok "$repo @ $branch ($(git -C "apps/$dir" rev-parse --short HEAD))"
  done
}

compose() { docker compose --env-file .env "$@"; }

# Espace libre (en Ko) sur le disque qui porte un dossier.
libre_ko() { df -Pk "$1" | awk 'NR==2 { print $4 }'; }

# Un journal ne grossit pas sans fin : au-delà de 5 Mo, son contenu passe dans <journal>.1 (un seul ancien gardé).
# Copie puis remise à zéro : le cron, qui écrit en ajout (>>), continue dans le même fichier.
tourner_journal() {
  [ -f "$1" ] || return 0
  [ "$(stat -c %s "$1")" -gt 5242880 ] || return 0
  cp -f "$1" "$1.1" && : > "$1"
}

# Contrôle une archive de sauvegarde : lisible jusqu'au bout, avec data/ et .env.
# La liste détaillée de son contenu (tar -tv) est écrite dans le fichier donné en second.
verifier_archive() {
  tar -tvzf "$1" > "$2" 2>/dev/null || return 1
  grep -qE ' data/$' "$2" && grep -qE ' \.env$' "$2"
}

# Génère les secrets absents de .env (utile aussi après l'ajout d'une app sur un VPS déjà installé).
ensure_secrets() {
  local key
  for key in SESSION_SECRET POSTGRES_PASSWORD ATELIER_IMPORT_TOKEN APPS_SECRET_KEY PORTFOLIO_PROXY_SECRET; do
    if [ -z "$(env_get "$key")" ]; then env_set "$key" "$(openssl rand -hex 32)"; ok "$key généré"; fi
  done
}

# Dossiers de données et de médias (créés avant Docker pour en garder la propriété).
ensure_dirs() {
  mkdir -p data/viz data/convert data/projets data/nexus data/atelier_tab/exports \
           data/cine data/savoir data/tresorerie data/wiki data/hub data/formulaire data/portfolio data/mission data/datamind media/films media/series
  # Le portfolio tourne sous l'utilisateur node (uid 1000) : il écrit ses messages de contact dans data/portfolio.
  chown 1000:1000 data/portfolio
  # Mission aussi (utilisateur node) : sa base SQLite vit dans data/mission.
  chown -R 1000:1000 data/mission
  # DataMind aussi (utilisateur node) : jeux de données et analyses dans data/datamind.
  chown -R 1000:1000 data/datamind
}

# IA du serveur : choisit le modèle selon la mémoire (une seule fois ; modifiable ensuite dans .env).
# Le reste de la suite occupe environ 2 Go : un modèle 8B (≈ 5 Go) demande ≥ 10 Go au total.
ensure_ia() {
  local model ram_mb
  model="$(env_get OLLAMA_MODEL)"
  if [ -z "$model" ]; then
    ram_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    if [ "$ram_mb" -ge 10000 ]; then model="llama3.1:8b"
    elif [ "$ram_mb" -ge 5000 ]; then model="llama3.2:3b"
    else
      model="llama3.2:1b"
      warn "Seulement ${ram_mb} Mo de mémoire : modèle d'IA réduit ($model), réponses de qualité limitée."
    fi
    env_set OLLAMA_MODEL "$model"
    ok "modèle d'IA : $model (mémoire du serveur : ${ram_mb} Mo)"
  fi
  # Sans clé Anthropic, Nexus utilise l'IA du serveur.
  if [ -z "$(env_get ANTHROPIC_API_KEY)" ] && [ "$(env_get NEXUS_LLM_PROVIDER)" = "anthropic" ]; then
    env_set NEXUS_LLM_PROVIDER ollama
    ok "Nexus : moteur par défaut = IA du serveur (aucune clé Anthropic)"
  fi
}

# Télécharge le modèle dans le service ollama (plusieurs Go la première fois, rien ensuite).
pull_model() {
  local model
  model="$(env_get OLLAMA_MODEL)"; model="${model:-llama3.1:8b}"
  compose up -d ollama >/dev/null
  for _ in $(seq 1 30); do
    compose exec -T ollama ollama list >/dev/null 2>&1 && break
    sleep 2
  done
  if compose exec -T ollama ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qxF "$model"; then
    ok "modèle d'IA $model déjà présent"
    return 0
  fi
  step "Téléchargement du modèle d'IA $model (plusieurs Go, une seule fois)"
  if compose exec -T ollama ollama pull "$model"; then
    ok "modèle $model prêt"
  else
    warn "Téléchargement du modèle impossible pour l'instant : relance sudo ./update.sh ia plus tard."
  fi
}
