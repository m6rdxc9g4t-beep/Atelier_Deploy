# syntax=docker/dockerfile:1
# Atelier Projets : API Fastify + Prisma/SQLite, sur 127.0.0.1:3000.
# L'interface est servie par Caddy (voir caddy/Dockerfile).

# CLI Claude Code (Claude avec le forfait, CLAUDE_OAUTH_TOKEN) : version épinglée par docker-compose.yml
# (x-build-claude), la même dans toute la suite. Binaire natif autonome : ni node ni npm à l'exécution.
# Seul « --version » est lancé ici (jamais une demande) : il prouve que le vrai binaire est en place, à la bonne version.
FROM node:22-bookworm-slim AS claude
ARG CLAUDE_CODE_VERSION
RUN test -n "$CLAUDE_CODE_VERSION" || (echo "CLAUDE_CODE_VERSION manquant (docker-compose.yml, x-build-claude)" && exit 1)
RUN npm install -g --no-audit --no-fund "@anthropic-ai/claude-code@$CLAUDE_CODE_VERSION" \
    && /usr/local/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe --version | grep -qF "$CLAUDE_CODE_VERSION"

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
# CLI Claude Code (voir l'étape « claude ») : l'app la cherche à CLAUDE_CLI, la lance isolée, et ne lui donne le jeton
# du forfait que pour une demande, jamais la clé API.
COPY --from=claude /usr/local/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe /usr/local/bin/claude
RUN ["/usr/local/bin/claude", "--version"]

ENV NODE_ENV=production \
    HOST=127.0.0.1 \
    PORT=3000 \
    DATABASE_URL=file:/data/projets.db \
    BACKUP_DIR=/data/backups \
    CLAUDE_CLI=/usr/local/bin/claude

# Au démarrage : sauvegarde + migrations (prisma migrate deploy), puis l'API.
# Le jeton du forfait (CLAUDE_OAUTH_TOKEN) n'est pas donné aux migrations (env -u), et l'API est lancée par node
# lui-même (ce que fait « npm start ») : aucun npm ne le garde en mémoire. L'API le lit puis le retire de son
# environnement : seule la CLI isolée le reçoit.
CMD ["sh", "-c", "mkdir -p /data/backups && env -u CLAUDE_OAUTH_TOKEN npm run db:deploy --workspace=@atelier/backend && cd backend && exec node dist/server.js"]
