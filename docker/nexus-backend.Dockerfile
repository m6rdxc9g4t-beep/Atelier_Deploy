# syntax=docker/dockerfile:1
# Atelier Nexus, backend FastAPI sur 127.0.0.1:8100.
# Embarque Node + le serveur MCP d'Atelier Tab pour que les workflows puissent écrire dans Tab.

# CLI Claude Code (Claude avec le forfait, CLAUDE_OAUTH_TOKEN) : version épinglée par docker-compose.yml
# (x-build-claude), la même dans toute la suite. Binaire natif autonome : ni node ni npm à l'exécution.
# Seul « --version » est lancé ici (jamais une demande) : il prouve que le vrai binaire est en place, à la bonne version.
FROM node:22-bookworm-slim AS claude
ARG CLAUDE_CODE_VERSION
RUN test -n "$CLAUDE_CODE_VERSION" || (echo "CLAUDE_CODE_VERSION manquant (docker-compose.yml, x-build-claude)" && exit 1)
RUN npm install -g --no-audit --no-fund "@anthropic-ai/claude-code@$CLAUDE_CODE_VERSION" \
    && /usr/local/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe --version | grep -qF "$CLAUDE_CODE_VERSION"

# Mêmes premières étapes que caddy/Dockerfile : le cache Docker les partage.
FROM node:22-bookworm-slim AS tab
ENV ELECTRON_SKIP_BINARY_DOWNLOAD=1 CI=1
WORKDIR /src
COPY apps/atelier-tab/package.json apps/atelier-tab/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY apps/atelier-tab/ ./
RUN npm run build:desktop

FROM python:3.12-slim-bookworm
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libstdc++6 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=tab /usr/local/bin/node /usr/local/bin/node
WORKDIR /app
COPY apps/atelier_nexus/backend/requirements.txt ./
RUN pip install -r requirements.txt
COPY apps/atelier_nexus/backend/ ./
RUN rm -f .env
COPY --from=tab /src/dist-desktop/atelier-mcp.mjs /opt/atelier-tab/atelier-mcp.mjs
# Exemples de la suite : ceux de Tab à côté de son serveur MCP (load_suite_example), ceux de Nexus
COPY --from=tab /src/exemples-suite /opt/atelier-tab/exemples-suite
COPY apps/atelier_nexus/exemples-suite /opt/nexus/exemples-suite
# CLI Claude Code (voir l'étape « claude ») : l'app la cherche à CLAUDE_CLI_PATH (nom propre à Nexus), la lance isolée, et ne lui donne le jeton
# du forfait que pour une demande, jamais la clé API.
COPY --from=claude /usr/local/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe /usr/local/bin/claude
RUN ["/usr/local/bin/claude", "--version"]

ENV APP_ENV=production \
    HOME=/data/nexus \
    TAB_MCP_COMMAND="node /opt/atelier-tab/atelier-mcp.mjs" \
    TAB_DATA_DIR=/data/atelier_tab \
    TAB_EXPORTS_DIR=/data/atelier_tab/exports \
    EXEMPLES_DIR=/opt/nexus/exemples-suite \
    DATA_VIA_BASE_URL=http://127.0.0.1:8000/api \
    PROJETS_BASE_URL=http://127.0.0.1:3000/api \
    CLAUDE_CLI_PATH=/usr/local/bin/claude

# Le dossier courant est /data/nexus (volume) : c'est là que vit le `.env` que l'écran
# Réglages de Nexus lit et réécrit, il survit donc aux mises à jour de l'image.
WORKDIR /data/nexus
CMD ["uvicorn", "--app-dir", "/app", "main:app", "--host", "127.0.0.1", "--port", "8100", \
     "--proxy-headers", "--forwarded-allow-ips", "127.0.0.1"]
