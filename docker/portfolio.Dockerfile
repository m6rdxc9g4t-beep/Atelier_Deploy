# syntax=docker/dockerfile:1
# Atelier Portfolio : site public de François Pichon (API Express + interface React), sur 127.0.0.1:8787.
# Pas de connexion au portail : c'est la vitrine destinée aux recruteurs.
# Messages du formulaire de contact dans data/portfolio/messages.jsonl.

# Données publiques DVF (ventes immobilières, Etalab) pour la démo « Observatoire immobilier » :
# téléchargées et agrégées ici, dans une étape à part, pour n'être refaites qu'une fois par mois
# (DVF_CACHE_KEY = mois courant) ou quand le script change. Un échec réseau ne bloque pas la construction :
# la démo affiche alors « Données en préparation ».
FROM node:22-bookworm-slim AS dvf
ARG DVF_CACHE_KEY=
ARG DVF_DEPARTEMENTS=49,62,59,44,35
WORKDIR /app
COPY apps/atelier_portefolio/scripts/dvf ./scripts/dvf
RUN mkdir -p client/public/data/dvf \
    && if [ -f scripts/dvf/fetch-dvf.mjs ]; then \
         echo "DVF ${DVF_CACHE_KEY} : départements ${DVF_DEPARTEMENTS}" \
         && DVF_DEPARTEMENTS="${DVF_DEPARTEMENTS}" DVF_OPTIONAL=1 node scripts/dvf/fetch-dvf.mjs || true; \
       fi

FROM node:22-bookworm-slim AS build
ENV CI=1
WORKDIR /app
COPY apps/atelier_portefolio/package.json apps/atelier_portefolio/package-lock.json ./
COPY apps/atelier_portefolio/shared/package.json shared/
COPY apps/atelier_portefolio/server/package.json server/
COPY apps/atelier_portefolio/client/package.json client/
RUN npm ci --no-audit --no-fund
COPY apps/atelier_portefolio/ ./
COPY --from=dvf /app/client/public/data/dvf ./client/public/data/dvf
RUN npm run build && npm prune --omit=dev

FROM node:22-bookworm-slim
WORKDIR /app
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/shared/package.json ./shared/package.json
COPY --from=build /app/shared/dist ./shared/dist
COPY --from=build /app/server/package.json ./server/package.json
COPY --from=build /app/server/dist ./server/dist
COPY --from=build /app/server/data ./server/data
COPY --from=build /app/client/dist ./client/dist

ENV NODE_ENV=production \
    HOST=127.0.0.1 \
    PORT=8787 \
    MESSAGES_FILE=/data/messages.jsonl

# Utilisateur node (uid 1000) : data/portfolio lui appartient (ensure_dirs).
USER node
CMD ["node", "server/dist/index.js"]
