# syntax=docker/dockerfile:1
# DataMind (dépôt Agent_Data) : agent d'analyse de données.
# Un seul processus Node sur 127.0.0.1:3600 : l'API Fastify (DuckDB) sert aussi l'interface React compilée (STATIC_DIR).
# Jeux de données (Parquet) et analyses (JSON) dans /data.

FROM node:22-bookworm-slim AS build
ENV CI=1
WORKDIR /app
COPY apps/agent_data/package.json apps/agent_data/package-lock.json ./
COPY apps/agent_data/backend/package.json backend/
COPY apps/agent_data/frontend/package.json frontend/
RUN npm ci --include=dev --no-audit --no-fund
COPY apps/agent_data/ ./
RUN npm run build && npm prune --omit=dev --no-audit --no-fund

FROM node:22-bookworm-slim
ENV NODE_ENV=production \
    HOST=127.0.0.1 \
    PORT=3600 \
    DATA_DIR=/data \
    STATIC_DIR=/app/frontend/dist \
    SAMPLES_DIR=/app/sample_data
WORKDIR /app
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/backend/package.json ./backend/
COPY --from=build /app/backend/dist ./backend/dist
COPY --from=build /app/frontend/dist ./frontend/dist
COPY --from=build /app/sample_data ./sample_data
USER node
CMD ["node", "backend/dist/server.js"]
