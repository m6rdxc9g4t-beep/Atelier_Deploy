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

# sync_apps                         toutes les apps passent au dernier commit de leur branche
# sync_apps --seulement [dossier…]  seuls ces dossiers avancent ; les autres ne sont que clonés s'ils manquent
#                                   (l'image de Caddy contient Tab et Projets, celle de Nexus le MCP de Tab).
# Le code d'une app n'avance que si ses services sont reconstruits dans la foulée : sinon l'interface servie par
# Caddy et l'API en service ne seraient plus de la même version, et auto-update.sh croirait l'app à jour.
sync_apps() {
  local owner entry dir repo branch_var branch seulement=0
  if [ "${1:-}" = "--seulement" ]; then seulement=1; shift; fi
  owner="$(env_get GITHUB_OWNER)"; owner="${owner:-m6rdxc9g4t-beep}"
  mkdir -p apps
  for entry in "${APPS[@]}"; do
    IFS='|' read -r dir repo branch_var <<<"$entry"
    branch="$(env_get "$branch_var")"; branch="${branch:-main}"
    if [ -d "apps/$dir/.git" ]; then
      if [ "$seulement" -eq 1 ] && [[ " $* " != *" $dir "* ]]; then continue; fi
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

# ── Construction et lancement, un service à la fois ─────────────────────────
# Le disque du VPS est petit (40 Go) : une reconstruction garde l'ancienne image (en service) à côté de la
# nouvelle, plus le cache de construction. Tout reconstruire d'un coup demande donc plus de 10 Go libres.
# On reconstruit une app à la fois : construire, relancer, supprimer l'ancienne image et le cache, puis la suivante.
libre_go() { echo $(( $(libre_ko "$ROOT") / 1048576 )); }
nettoyer() {
  docker image prune -f >/dev/null 2>&1 || true
  docker builder prune -af >/dev/null 2>&1 || warn "nettoyage du cache de construction impossible"
}

# Avant de toucher aux conteneurs : Docker répond et connaît ce que docker-compose.yml lui demande.
verifier_docker() {
  local version majeur
  version="$(docker version --format '{{.Server.Version}}' 2>/dev/null)" || die "Docker ne répond pas (sudo systemctl status docker)."
  majeur="${version%%.*}"
  if ! [[ "$majeur" =~ ^[0-9]+$ ]] || [ "$majeur" -lt 25 ]; then
    die "Docker $version est trop ancien (il faut la version 25 ou une plus récente). Mets-le à jour : curl -fsSL https://get.docker.com | sudo sh, puis relance."
  fi
}

# Image construite par compose pour un service (projet « atelier ») ; rien pour un service sans construction.
image_de() { case "$1" in ollama|postgres|datamind-demo) ;; *) echo "atelier-$1" ;; esac; }

# Délai laissé à un service pour répondre à sa sonde après son lancement (secondes).
ATTENTE_SERVICE=300

# Construit un service, le relance et attend qu'il réponde à sa sonde. Rend 1 si la nouvelle version n'est pas en
# service : construction impossible (rien n'a été touché), ou redémarrage raté (l'image précédente, gardée le temps de
# l'essai, est alors remise en service).
deployer() {
  local service="$1" image precedent=0
  image="$(image_de "$service")"
  [ "$(libre_go)" -ge 3 ] || die "moins de 3 Go libres sur le disque : libère de la place (df -h /, sudo docker system df) puis relance"
  if [ -n "$image" ] && docker image inspect "$image:latest" >/dev/null 2>&1; then
    if docker tag "$image:latest" "$image:precedent"; then precedent=1; fi
  fi
  if ! compose build "$service"; then
    [ "$precedent" -eq 0 ] || docker rmi "$image:precedent" >/dev/null 2>&1 || true
    warn "$service : construction impossible (voir ci-dessus) ; la version en service n'a pas été touchée"
    return 1
  fi
  if compose up -d --wait --wait-timeout "$ATTENTE_SERVICE" "$service"; then
    [ "$precedent" -eq 0 ] || docker rmi "$image:precedent" >/dev/null 2>&1 || true
    return 0
  fi
  warn "$service ne redémarre pas. Dernières lignes de son journal :"
  compose logs --no-color --tail 30 "$service" 2>&1 | sed 's/^/    /' || true
  if [ "$precedent" -eq 0 ]; then
    warn "$service : pas de version précédente à remettre en service (sudo docker compose logs $service)"
  else
    docker tag "$image:precedent" "$image:latest" || true
    if compose up -d --no-build --wait --wait-timeout "$ATTENTE_SERVICE" "$service"; then
      docker rmi "$image:precedent" >/dev/null 2>&1 || true
      warn "$service : la nouvelle version ne démarre pas, la version précédente a été remise en service."
      warn "Une migration de base déjà appliquée n'est pas défaite : vérifie l'app avant de corriger et de relancer."
    else
      warn "$service : ni la nouvelle version ni la précédente ne démarrent (sudo docker compose logs $service)."
      warn "L'image précédente reste disponible sous le nom $image:precedent."
    fi
  fi
  return 1
}

# Déploie les services donnés, un par un. Un service en échec n'arrête pas les suivants : ils sont listés dans RATES,
# et la fonction rend 1 s'il y en a.
RATES=()
deployer_services() {
  local service
  RATES=()
  for service in "$@"; do
    if deployer "$service"; then ok "$service à jour et en service (espace libre : $(libre_go) Go)"
    else RATES+=("$service"); fi
    nettoyer
  done
  [ ${#RATES[@]} -eq 0 ]
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
