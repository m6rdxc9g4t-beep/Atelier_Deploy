# syntax=docker/dockerfile:1
# Atelier Dates (Notre Petit Monde) : Next.js sur 127.0.0.1:3400.
# Les données restent dans Supabase (la même base que la version Vercel) : rien n'est stocké sur le VPS.
# Les variables NEXT_PUBLIC_* sont inscrites dans l'interface au moment de la construction.

FROM node:22-bookworm-slim AS build
ENV CI=1 NEXT_TELEMETRY_DISABLED=1
WORKDIR /app
COPY apps/atelier_dates/package.json apps/atelier_dates/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY apps/atelier_dates/ ./
ARG ATELIER_DOMAIN
ARG PROTO=https
ARG SUPABASE_URL
ARG SUPABASE_PUBLISHABLE_KEY
ARG VAPID_PUBLIC_KEY=
RUN test -n "$ATELIER_DOMAIN" || (echo "ATELIER_DOMAIN manquant" && exit 1)
RUN test -n "$SUPABASE_URL" && test -n "$SUPABASE_PUBLISHABLE_KEY" \
    || (echo "Adresse ou clé Supabase de Dates manquante" && exit 1)
RUN NEXT_PUBLIC_SUPABASE_URL="$SUPABASE_URL" \
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY" \
    NEXT_PUBLIC_SITE_URL="$PROTO://dates.$ATELIER_DOMAIN" \
    NEXT_PUBLIC_APP_TIMEZONE="Europe/Paris" \
    NEXT_PUBLIC_VAPID_PUBLIC_KEY="$VAPID_PUBLIC_KEY" \
    npm run build \
    && npm prune --omit=dev --no-audit --no-fund

FROM node:22-bookworm-slim
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1
WORKDIR /app
COPY --from=build /app/package.json /app/next.config.ts ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/public ./public
COPY --from=build /app/.next ./.next
USER node
CMD ["node_modules/.bin/next", "start", "--hostname", "127.0.0.1", "--port", "3400"]
