# syntax=docker/dockerfile:1
# Atelier Projets : API Fastify + Prisma/SQLite, sur 127.0.0.1:3000.
# L'interface est servie par Caddy (voir caddy/Dockerfile).

# Mêmes premières étapes que caddy/Dockerfile : le cache Docker les partage.
FROM node:24-bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
ENV ELECTRON_SKIP_BINARY_DOWNLOAD=1 CI=1
WORKDIR /app
COPY apps/atelier_projets/package.json apps/atelier_projets/package-lock.json ./
COPY apps/atelier_projets/backend/package.json backend/
COPY apps/atelier_projets/frontend/package.json frontend/
COPY apps/atelier_projets/design-system/package.json design-system/
COPY apps/atelier_projets/desktop/package.json desktop/
RUN npm ci --include=dev --no-audit --no-fund
COPY apps/atelier_projets/ ./

# Client Prisma (non versionné) puis compilation TypeScript du backend.
RUN npm run db:generate --workspace=@atelier/backend \
    && npm run build --workspace=@atelier/backend

ENV NODE_ENV=production \
    HOST=127.0.0.1 \
    PORT=3000 \
    DATABASE_URL=file:/data/projets.db \
    BACKUP_DIR=/data/backups

# Au démarrage : sauvegarde + migrations (prisma migrate deploy), puis l'API.
CMD ["sh", "-c", "mkdir -p /data/backups && npm run db:deploy --workspace=@atelier/backend && exec npm start --workspace=@atelier/backend"]
