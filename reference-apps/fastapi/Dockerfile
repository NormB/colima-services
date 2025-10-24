FROM python:3.11-slim

WORKDIR /app

# Install dependencies (add wget and jq for Vault integration)
RUN apt-get update && apt-get install -y wget jq && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app/ ./app/

# Copy startup scripts
COPY start.sh /app/start.sh
COPY init.sh /app/init.sh
RUN chmod +x /app/start.sh /app/init.sh

# Expose ports (HTTP and HTTPS)
EXPOSE 8000 8443

# Run initialization script (which calls start.sh)
CMD ["/app/init.sh"]
