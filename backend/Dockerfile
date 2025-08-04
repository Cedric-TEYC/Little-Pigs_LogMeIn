FROM python:3.11-slim

WORKDIR /app

# MAJ OS et nettoyage
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install deps Python
COPY requirements.txt .
RUN pip install --upgrade pip \
    && pip install --no-cache-dir --upgrade -r requirements.txt

COPY . .

CMD ["python", "app.py"]
