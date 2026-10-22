# syntax=docker/dockerfile:1
# Atelier Convert : API FastAPI qui sert aussi son interface, sur 127.0.0.1:8010.
# Tesseract (français + anglais) est installé pour l'OCR des relevés scannés et des photos.

ARG PROTO=https

FROM node:22-bookworm-slim AS front
WORKDIR /src
COPY apps/atelier_convert/frontend/package.json apps/atelier_convert/frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY apps/atelier_convert/frontend/ ./
ARG ATELIER_DOMAIN
ARG PROTO
RUN VITE_ATELIER_CONVERT_URL="$PROTO://convert.$ATELIER_DOMAIN" \
    VITE_ATELIER_VIZ_URL="$PROTO://viz.$ATELIER_DOMAIN" \
    VITE_ATELIER_TAB_URL="$PROTO://tab.$ATELIER_DOMAIN" \
    VITE_ATELIER_PROJETS_URL="$PROTO://projets.$ATELIER_DOMAIN" \
    npm run build

FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends tesseract-ocr tesseract-ocr-fra \
    && rm -rf /var/lib/apt/lists/*
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY apps/atelier_convert/backend/requirements.txt ./
RUN pip install -r requirements.txt
COPY apps/atelier_convert/backend/ ./
COPY apps/atelier_convert/samples /opt/convert/samples
COPY --from=front /src/dist /opt/convert/frontend

ENV APP_ENV=production \
    DATA_DIR=/data \
    FRONTEND_DIST=/opt/convert/frontend \
    SAMPLES_DIR=/opt/convert/samples \
    SERVE_FRONTEND=true \
    CONVERT_OCR_TESSERACT=/usr/bin/tesseract \
    ATELIER_TAB_DATA_DIR=/data-tab

CMD ["uvicorn", "main:app", "--host", "127.0.0.1", "--port", "8010", "--workers", "1", \
     "--proxy-headers", "--forwarded-allow-ips", "127.0.0.1"]
