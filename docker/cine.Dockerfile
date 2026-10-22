# syntax=docker/dockerfile:1
# Atelier Ciné : API Express qui sert aussi son interface, sur 127.0.0.1:4000.
# Les vidéos sont lues dans media/ (lecture seule), le catalogue dans data/cine/.

FROM node:22-bookworm-slim AS build
ENV ELECTRON_SKIP_BINARY_DOWNLOAD=1 CI=1
WORKDIR /app
COPY apps/atelier_cine/package.json apps/atelier_cine/package-lock.json ./
COPY apps/atelier_cine/frontend/package.json frontend/
COPY apps/atelier_cine/backend/package.json backend/
COPY apps/atelier_cine/desktop/package.json desktop/
RUN npm ci --no-audit --no-fund
COPY apps/atelier_cine/ ./
RUN npm run build

FROM node:22-bookworm-slim
# ffprobe : lecture des durées et codecs quand SCAN_PROBE=true
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*
ENV ELECTRON_SKIP_BINARY_DOWNLOAD=1 CI=1
WORKDIR /app
COPY apps/atelier_cine/package.json apps/atelier_cine/package-lock.json ./
COPY apps/atelier_cine/frontend/package.json frontend/
COPY apps/atelier_cine/backend/package.json backend/
COPY apps/atelier_cine/desktop/package.json desktop/
RUN npm ci --omit=dev --workspace=backend --no-audit --no-fund
COPY apps/atelier_cine/backend/ backend/
COPY --from=build /app/frontend/dist frontend/dist

ENV NODE_ENV=production \
    PORT=4000 \
    ATELIER_DATA_DIR=/data \
    ATELIER_FRONTEND_DIST=/app/frontend/dist \
    MEDIA_MOVIES_DIRS=/media/films \
    MEDIA_SHOWS_DIRS=/media/series

WORKDIR /app/backend
# server.js écoute sur toutes les interfaces : on passe par startServer pour rester sur 127.0.0.1.
CMD ["node", "-e", "import('./src/start.js').then(m=>m.startServer({host:'127.0.0.1'})).catch(e=>{console.error(e);process.exit(1)})"]
