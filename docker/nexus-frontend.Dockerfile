# syntax=docker/dockerfile:1
# Atelier Nexus, interface Next.js (sortie standalone) sur 127.0.0.1:3100.
# Repris du Dockerfile du dépôt, avec les adresses de la suite figées au build
# et l'API appelée sur la même origine (Caddy envoie /api/* au backend).

ARG PROTO=https

FROM node:22-alpine AS deps
WORKDIR /app
COPY apps/atelier_nexus/frontend/package.json apps/atelier_nexus/frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund

FROM node:22-alpine AS builder
WORKDIR /app
ARG ATELIER_DOMAIN
ARG PROTO
# Les variables NEXT_PUBLIC_* sont inlinées au build. API vide = même origine.
ENV NEXT_TELEMETRY_DISABLED=1 \
    NEXT_PUBLIC_API_URL="" \
    NEXT_PUBLIC_ATELIER_NEXUS_URL="$PROTO://nexus.$ATELIER_DOMAIN" \
    NEXT_PUBLIC_ATELIER_VIZ_URL="$PROTO://viz.$ATELIER_DOMAIN" \
    NEXT_PUBLIC_ATELIER_TAB_URL="$PROTO://tab.$ATELIER_DOMAIN" \
    NEXT_PUBLIC_ATELIER_PROJETS_URL="$PROTO://projets.$ATELIER_DOMAIN" \
    NEXT_PUBLIC_ATELIER_PROJETS_API_URL="$PROTO://projets.$ATELIER_DOMAIN"
COPY --from=deps /app/node_modules ./node_modules
COPY apps/atelier_nexus/frontend/ ./
RUN rm -f .env .env.local .env.production .env.production.local && npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3100 \
    HOSTNAME=127.0.0.1
RUN addgroup -S nodejs && adduser -S nextjs -G nodejs
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
CMD ["node", "server.js"]
