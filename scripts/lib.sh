#!/usr/bin/env bash
# Fonctions communes à install.sh, update.sh et backup.sh.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bold=$'\e[1m'; dim=$'\e[2m'; red=$'\e[31m'; green=$'\e[32m'; yellow=$'\e[33m'; reset=$'\e[0m'
step() { printf '\n%s▸ %s%s\n' "$bold" "$*" "$reset"; }
ok()   { printf '  %s✓%s %s\n' "$green" "$reset" "$*"; }
warn() { printf '  %s!%s %s\n' "$yellow" "$reset" "$*"; }
die()  { printf '\n%s✗ %s%s\n' "$red" "$*" "$reset" >&2; exit 1; }

# Lit une valeur de .env (sans exécuter le fichier).
env_get() {
  [ -f .env ] || return 0
  grep -E "^$1=" .env | tail -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//'
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
  "atelier_projets|Atelier_Projets|BRANCH_PROJETS"
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
