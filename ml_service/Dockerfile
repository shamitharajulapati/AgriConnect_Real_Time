FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

# Use shell form (not exec form) so $PORT expands correctly
CMD sh -c "gunicorn -w 2 -b 0.0.0.0:${PORT:-8080} -t 120 --log-level info app:app"
