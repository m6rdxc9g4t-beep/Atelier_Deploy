# syntax=docker/dockerfile:1
# Atelier Mission (section « Sites & tests ») : mini-CRM freelance (prospects, devis, factures, relances).
# Un seul processus Node sur 127.0.0.1:3500 : l'API Fastify (SQLite) sert aussi l'interface compilée (STATIC_DIR).
# Projets (127.0.0.1:3000) et Trésorerie (127.0.0.1:5050) sont joints en local, sur ce même VPS.

# Mêmes premières étapes que projets.Dockerfile : le cache Docker les partage.
FROM node:24-bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
ENV CI=1
WORKDIR /app
COPY apps/atelier_mission/package.json apps/atelier_mission/package-lock.json ./
COPY apps/atelier_mission/backend/package.json backend/
COPY apps/atelier_mission/frontend/package.json frontend/
COPY apps/atelier_mission/design-system/package.json design-system/
RUN npm ci --include=dev --no-audit --no-fund
COPY apps/atelier_mission/ ./
ARG ATELIER_DOMAIN
ARG PROTO=https
RUN test -n "$ATELIER_DOMAIN" || (echo "ATELIER_DOMAIN manquant" && exit 1)
# Sélecteur de suite de l'en-tête : les autres apps à leurs adresses publiques.
RUN VITE_ATELIER_PROJETS_URL="$PROTO://projets.$ATELIER_DOMAIN" \
    VITE_ATELIER_TRESORERIE_URL="$PROTO://tresorerie.$ATELIER_DOMAIN" \
    VITE_ATELIER_VIZ_URL="$PROTO://viz.$ATELIER_DOMAIN" \
    VITE_ATELIER_TAB_URL="$PROTO://tab.$ATELIER_DOMAIN" \
    npm run build \
    && npm prune --omit=dev --no-audit --no-fund

FROM node:24-bookworm-slim
ENV NODE_ENV=production \
    HOST=127.0.0.1 \
    PORT=3500 \
    DATABASE_PATH=/data/atelier-mission.db \
    STATIC_DIR=/app/frontend/dist
WORKDIR /app
# backend/ : dist, migrations (drizzle/) appliquées au démarrage, polices et profil ICC du Factur-X (assets/).
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/backend ./backend
COPY --from=build /app/frontend/dist ./frontend/dist
USER node
CMD ["node", "backend/dist/server.js"]
