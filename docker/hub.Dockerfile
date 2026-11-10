# syntax=docker/dockerfile:1
# Atelier Hub : API Fastify + SQLite, qui sert aussi son interface, sur 127.0.0.1:3700.
# Lit les autres apps de la suite en 127.0.0.1 (lecture seule) et l'index de Tab (data/atelier_tab/exports).

ARG PROTO=https

FROM node:24-bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ENV CI=1
WORKDIR /app
COPY apps/atelier_hub/package.json apps/atelier_hub/package-lock.json ./
COPY apps/atelier_hub/backend/package.json backend/
COPY apps/atelier_hub/frontend/package.json frontend/
RUN npm ci --include=dev --no-audit --no-fund
COPY apps/atelier_hub/ ./
ARG ATELIER_DOMAIN
ARG PROTO
RUN test -n "$ATELIER_DOMAIN" || (echo "ATELIER_DOMAIN manquant" && exit 1)
# Adresses du sélecteur « Suite Atelier » : les sous-domaines de la suite.
RUN VITE_ATELIER_NEXUS_URL="$PROTO://nexus.$ATELIER_DOMAIN" \
    VITE_ATELIER_VIZ_URL="$PROTO://viz.$ATELIER_DOMAIN" \
    VITE_ATELIER_TAB_URL="$PROTO://tab.$ATELIER_DOMAIN" \
    VITE_ATELIER_PROJETS_URL="$PROTO://projets.$ATELIER_DOMAIN" \
    VITE_ATELIER_WIKI_URL="$PROTO://wiki.$ATELIER_DOMAIN" \
    VITE_ATELIER_CONVERT_URL="$PROTO://convert.$ATELIER_DOMAIN" \
    VITE_ATELIER_PORTAL_URL="$PROTO://$ATELIER_DOMAIN" \
    npm run build \
    && npm prune --omit=dev --no-audit --no-fund

FROM node:24-bookworm-slim
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/backend/package.json ./backend/
COPY --from=build /app/backend/dist ./backend/dist
COPY --from=build /app/frontend/dist ./frontend/dist

ENV HOST=127.0.0.1 \
    PORT=3700 \
    HUB_DATA_DIR=/data \
    HUB_STATIC_DIR=/app/frontend/dist \
    TAB_EXPORTS_DIR=/tab-exports

# Un seul processus : SQLite n'a qu'un écrivain ; les migrations tournent au démarrage.
CMD ["node", "backend/dist/server.js"]
