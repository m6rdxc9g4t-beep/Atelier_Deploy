# syntax=docker/dockerfile:1
# Agent Ops Lab (section « Sites & tests ») : simulation logistique pilotée par un agent IA,
# serveur Next.js autonome sur 127.0.0.1:3400.
# Toute la simulation tourne dans le navigateur (sauvegarde en localStorage) : aucune donnée côté serveur, aucun volume.

FROM node:22-bookworm-slim AS build
ENV CI=1 NEXT_TELEMETRY_DISABLED=1
WORKDIR /app
COPY apps/agent-ops-lab/package.json apps/agent-ops-lab/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY apps/agent-ops-lab/ ./
# « prebuild » copie le worker de MapLibre dans public/ avant la compilation.
RUN npm run build

FROM node:22-bookworm-slim
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    HOSTNAME=127.0.0.1 \
    PORT=3400
WORKDIR /app
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
COPY --from=build /app/public ./public
USER node
CMD ["node", "server.js"]
