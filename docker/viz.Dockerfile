# syntax=docker/dockerfile:1
# Atelier Viz : API FastAPI + DuckDB, qui sert aussi son interface, sur 127.0.0.1:8000.

ARG PROTO=https

FROM node:22-bookworm-slim AS front
WORKDIR /src
COPY apps/atelier_viz/frontend/package.json apps/atelier_viz/frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY apps/atelier_viz/frontend/ ./
ARG ATELIER_DOMAIN
ARG PROTO
RUN VITE_ATELIER_VIZ_URL="$PROTO://viz.$ATELIER_DOMAIN" \
    VITE_ATELIER_TAB_URL="$PROTO://tab.$ATELIER_DOMAIN" \
    VITE_ATELIER_PROJETS_URL="$PROTO://projets.$ATELIER_DOMAIN" \
    npm run build

FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY apps/atelier_viz/backend/requirements.txt ./
RUN pip install -r requirements.txt
COPY apps/atelier_viz/backend/ ./
COPY apps/atelier_viz/samples /opt/viz/samples
COPY --from=front /src/dist /opt/viz/frontend

ENV APP_ENV=production \
    DATA_DIR=/data \
    FRONTEND_DIST=/opt/viz/frontend \
    SAMPLES_DIR=/opt/viz/samples \
    SERVE_FRONTEND=true \
    SECRETS_BACKEND=file \
    SYSTEM_NOTIFICATIONS=false \
    ATELIER_PROJETS_URL=http://127.0.0.1:3000 \
    ATELIER_TAB_EXPORTS_DIR=/data-tab/exports

# Un seul worker : DuckDB n'accepte qu'un programme à la fois, et le planificateur vit dans le processus.
CMD ["uvicorn", "main:app", "--host", "127.0.0.1", "--port", "8000", "--workers", "1", \
     "--proxy-headers", "--forwarded-allow-ips", "127.0.0.1"]
