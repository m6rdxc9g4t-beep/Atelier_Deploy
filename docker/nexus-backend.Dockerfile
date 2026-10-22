# syntax=docker/dockerfile:1
# Atelier Nexus, backend FastAPI sur 127.0.0.1:8100.
# Embarque Node + le serveur MCP d'Atelier Tab pour que les workflows puissent écrire dans Tab.

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

ENV APP_ENV=production \
    HOME=/data/nexus \
    TAB_MCP_COMMAND="node /opt/atelier-tab/atelier-mcp.mjs" \
    TAB_DATA_DIR=/data/atelier_tab \
    TAB_EXPORTS_DIR=/data/atelier_tab/exports \
    DATA_VIA_BASE_URL=http://127.0.0.1:8000/api \
    PROJETS_BASE_URL=http://127.0.0.1:3000/api

# Le dossier courant est /data/nexus (volume) : c'est là que vit le `.env` que l'écran
# Réglages de Nexus lit et réécrit, il survit donc aux mises à jour de l'image.
WORKDIR /data/nexus
CMD ["uvicorn", "--app-dir", "/app", "main:app", "--host", "127.0.0.1", "--port", "8100", \
     "--proxy-headers", "--forwarded-allow-ips", "127.0.0.1"]
