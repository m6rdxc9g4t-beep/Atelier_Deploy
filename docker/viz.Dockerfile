# syntax=docker/dockerfile:1
# Atelier Viz : API FastAPI + DuckDB, qui sert aussi son interface, sur 127.0.0.1:8000.

ARG PROTO=https

# CLI Claude Code (Claude avec le forfait, CLAUDE_OAUTH_TOKEN) : version épinglée par docker-compose.yml
# (x-build-claude), la même dans toute la suite. Binaire natif autonome : ni node ni npm à l'exécution.
# Seul « --version » est lancé ici (jamais une demande) : il prouve que le vrai binaire est en place, à la bonne version.
FROM node:22-bookworm-slim AS claude
ARG CLAUDE_CODE_VERSION
RUN test -n "$CLAUDE_CODE_VERSION" || (echo "CLAUDE_CODE_VERSION manquant (docker-compose.yml, x-build-claude)" && exit 1)
RUN npm install -g --no-audit --no-fund "@anthropic-ai/claude-code@$CLAUDE_CODE_VERSION" \
    && /usr/local/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe --version | grep -qF "$CLAUDE_CODE_VERSION"

FROM node:22-bookworm-slim AS front
WORKDIR /src
COPY apps/atelier_viz/frontend/package.json apps/atelier_viz/frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY apps/atelier_viz/frontend/ ./
ARG ATELIER_DOMAIN
ARG PROTO
RUN VITE_ATELIER_VIZ_URL="$PROTO://viz.$ATELIER_DOMAIN" \
    VITE_ATELIER_TAB_URL="$PROTO://tab.$ATELIER_DOMAIN" \
    VITE_ATELIER_PROJETS_URL="$PROTO://projets.$ATELIER_DOMAIN" \
    npm run build

FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY apps/atelier_viz/backend/requirements.txt ./
RUN pip install -r requirements.txt
# Pilotes des connecteurs de Viz (SQL Server, PostgreSQL, MySQL, Snowflake, BigQuery) : « Nouvelle connexion » ne dit
# plus « Pilote à installer ». Roues binaires pour Linux x86_64 et arm64 : aucun paquet système (FreeTDS et libpq sont
# dans les roues). Environ 145 Mo installés. SharePoint, SQLite et les fichiers n'en ont pas besoin.
COPY apps/atelier_viz/backend/requirements-connectors.txt ./
RUN pip install -r requirements-connectors.txt
COPY apps/atelier_viz/backend/ ./
COPY apps/atelier_viz/samples /opt/viz/samples
# Exemples de la suite (histoires fictives communes, générées par exemples/generer.py)
COPY apps/atelier_viz/exemples-suite /opt/viz/exemples-suite
COPY --from=front /src/dist /opt/viz/frontend
# CLI Claude Code (voir l'étape « claude ») : l'app la cherche à CLAUDE_CLI, la lance isolée, et ne lui donne le jeton
# du forfait que pour une demande, jamais la clé API.
COPY --from=claude /usr/local/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe /usr/local/bin/claude
RUN ["/usr/local/bin/claude", "--version"]

ENV APP_ENV=production \
    DATA_DIR=/data \
    FRONTEND_DIST=/opt/viz/frontend \
    SAMPLES_DIR=/opt/viz/samples \
    EXEMPLES_DIR=/opt/viz/exemples-suite \
    SERVE_FRONTEND=true \
    SECRETS_BACKEND=file \
    SYSTEM_NOTIFICATIONS=false \
    ATELIER_PROJETS_URL=http://127.0.0.1:3000 \
    ATELIER_TAB_EXPORTS_DIR=/data-tab/exports \
    CLAUDE_CLI=/usr/local/bin/claude

# Un seul worker : DuckDB n'accepte qu'un programme à la fois, et le planificateur vit dans le processus.
CMD ["uvicorn", "main:app", "--host", "127.0.0.1", "--port", "8000", "--workers", "1", \
     "--proxy-headers", "--forwarded-allow-ips", "127.0.0.1"]
