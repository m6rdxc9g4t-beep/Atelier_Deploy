# syntax=docker/dockerfile:1
# DataMind (dépôt Agent_Data) : agent d'analyse de données, interface Streamlit sur 127.0.0.1:8501.
# Le code écrit par l'IA s'exécute dans ce conteneur, sous un utilisateur sans privilèges.

FROM python:3.12-slim-bookworm
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 \
    MPLCONFIGDIR=/tmp/matplotlib \
    STREAMLIT_SERVER_ADDRESS=127.0.0.1 \
    STREAMLIT_SERVER_PORT=8501
RUN apt-get update && apt-get install -y --no-install-recommends tzdata fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY apps/agent_data/requirements.txt ./
RUN pip install -r requirements.txt
COPY apps/agent_data/ ./
RUN rm -f .env && useradd --create-home --uid 1000 datamind
USER datamind
CMD ["streamlit", "run", "app.py"]
