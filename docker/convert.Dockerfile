# syntax=docker/dockerfile:1
# Atelier Convert : API FastAPI qui sert aussi son interface, sur 127.0.0.1:8010.
# Tesseract (français + anglais) est installé pour l'OCR des relevés scannés et des photos.

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
COPY apps/atelier_convert/frontend/package.json apps/atelier_convert/frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY apps/atelier_convert/frontend/ ./
ARG ATELIER_DOMAIN
ARG PROTO
RUN VITE_ATELIER_CONVERT_URL="$PROTO://convert.$ATELIER_DOMAIN" \
    VITE_ATELIER_VIZ_URL="$PROTO://viz.$ATELIER_DOMAIN" \
    VITE_ATELIER_TAB_URL="$PROTO://tab.$ATELIER_DOMAIN" \
    VITE_ATELIER_PROJETS_URL="$PROTO://projets.$ATELIER_DOMAIN" \
    npm run build

FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends tesseract-ocr tesseract-ocr-fra \
    && rm -rf /var/lib/apt/lists/*
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY apps/atelier_convert/backend/requirements.txt ./
RUN pip install -r requirements.txt
COPY apps/atelier_convert/backend/ ./
COPY apps/atelier_convert/samples /opt/convert/samples
# Exemples de la suite (histoires fictives communes, générées par exemples/generer.py)
COPY apps/atelier_convert/exemples-suite /opt/convert/exemples-suite
COPY --from=front /src/dist /opt/convert/frontend
# CLI Claude Code (voir l'étape « claude ») : l'app la cherche à CLAUDE_CLI, la lance isolée, et ne lui donne le jeton
# du forfait que pour une demande, jamais la clé API.
COPY --from=claude /usr/local/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe /usr/local/bin/claude
RUN ["/usr/local/bin/claude", "--version"]

ENV APP_ENV=production \
    DATA_DIR=/data \
    FRONTEND_DIST=/opt/convert/frontend \
    SAMPLES_DIR=/opt/convert/samples \
    CONVERT_EXEMPLES_DIR=/opt/convert/exemples-suite \
    SERVE_FRONTEND=true \
    CONVERT_OCR_TESSERACT=/usr/bin/tesseract \
    ATELIER_TAB_DATA_DIR=/data-tab \
    CLAUDE_CLI=/usr/local/bin/claude

CMD ["uvicorn", "main:app", "--host", "127.0.0.1", "--port", "8010", "--workers", "1", \
     "--proxy-headers", "--forwarded-allow-ips", "127.0.0.1"]
