# syntax=docker/dockerfile:1
# Atelier Savoir : app Flask (cours, fiches, révisions) sur 127.0.0.1:5051.
# Le CSS Tailwind compilé est versionné : pas d'étape Node.

FROM python:3.12-slim-bookworm
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY apps/atelier-savoir/requirements.txt ./
RUN pip install -r requirements.txt gunicorn
COPY apps/atelier-savoir/ ./

ENV ATELIER_DB=/data/instance/savoir.db \
    ATELIER_UPLOADS=/data/uploads

# Un seul processus (les migrations tournent au démarrage, SQLite n'a qu'un écrivain) ;
# pas de délai : une génération de fiches enchaîne plusieurs appels à l'IA.
CMD ["gunicorn", "--bind", "127.0.0.1:5051", "--workers", "1", "--threads", "8", "--timeout", "0", \
     "--access-logfile", "-", "app:create_app()"]
