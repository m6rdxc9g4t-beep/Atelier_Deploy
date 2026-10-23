# syntax=docker/dockerfile:1
# Atelier Trésorerie : app Flask (comptes, budgets, imports) sur 127.0.0.1:5050.

FROM python:3.12-slim-bookworm
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
RUN apt-get update && apt-get install -y --no-install-recommends tzdata \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY apps/atelier_tr-sorerie/requirements.txt ./
RUN pip install -r requirements.txt gunicorn
COPY apps/atelier_tr-sorerie/ ./
RUN rm -f .env

ENV DATABASE_PATH=/data/finance.db \
    PORT=5050

# Un seul processus (migrations au démarrage, SQLite) ; pas de délai : sur le serveur, une réponse de l'IA peut prendre plusieurs minutes.
CMD ["gunicorn", "--bind", "127.0.0.1:5050", "--workers", "1", "--threads", "8", "--timeout", "0", \
     "--access-logfile", "-", "app:create_app()"]
