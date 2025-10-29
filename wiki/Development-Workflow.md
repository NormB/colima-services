# Development Workflow

## Table of Contents

- [Daily Development Routine](#daily-development-routine)
- [Starting Services](#starting-services)
- [Committing to Forgejo](#committing-to-forgejo)
- [Testing with Local Databases](#testing-with-local-databases)
- [Storing Secrets in Vault](#storing-secrets-in-vault)
- [Using RabbitMQ for Messaging](#using-rabbitmq-for-messaging)
- [Monitoring and Logging](#monitoring-and-logging)
- [Stopping Services](#stopping-services)

## Daily Development Routine

**Morning startup:**
```bash
cd ~/colima-services
./manage-colima.sh start
./manage-colima.sh health
```

**Check service status:**
```bash
./manage-colima.sh status
open http://localhost:3001  # Grafana
open http://localhost:3000  # Forgejo
```

**End of day:**
```bash
./manage-colima.sh stop
```

## Starting Services

```bash
# Start everything
./manage-colima.sh start

# Start specific services
docker compose up -d postgres redis-1 vault

# Check health
./manage-colima.sh health
```

## Committing to Forgejo

**Setup (first time):**
```bash
# Create repository in Forgejo UI
open http://localhost:3000

# Configure git remote
cd ~/my-project
git remote add forgejo http://localhost:3000/username/repo.git

# Or SSH
git remote add forgejo ssh://git@localhost:2222/username/repo.git
```

**Daily commits:**
```bash
git add .
git commit -m "Add feature"
git push forgejo main
```

## Testing with Local Databases

**PostgreSQL:**
```python
import psycopg2

conn = psycopg2.connect(
    host="localhost",
    port=5432,
    database="devdb",
    user="devuser",
    password=get_password_from_vault("postgres")
)

# Run tests
cursor = conn.cursor()
cursor.execute("SELECT * FROM users")
```

**MySQL:**
```python
import mysql.connector

conn = mysql.connector.connect(
    host="localhost",
    port=3306,
    database="devdb",
    user="devuser",
    password=get_password_from_vault("mysql")
)
```

**MongoDB:**
```python
from pymongo import MongoClient

client = MongoClient("mongodb://localhost:27017/")
db = client.devdb
collection = db.users
```

## Storing Secrets in Vault

**Store application secrets:**
```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Store API key
vault kv put secret/myapp api_key=abc123 api_secret=xyz789

# Retrieve in application
vault kv get -field=api_key secret/myapp
```

**In Python:**
```python
import hvac

client = hvac.Client(url='http://localhost:8200', token=vault_token)
secret = client.secrets.kv.v2.read_secret_version(path='myapp')
api_key = secret['data']['data']['api_key']
```

## Using RabbitMQ for Messaging

**Publish messages:**
```python
import pika

connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', 5672, '/',
        pika.PlainCredentials('devuser', password))
)
channel = connection.channel()
channel.queue_declare(queue='tasks', durable=True)
channel.basic_publish(
    exchange='',
    routing_key='tasks',
    body='Process this task'
)
```

**Consume messages:**
```python
def callback(ch, method, properties, body):
    print(f"Received: {body}")
    ch.basic_ack(delivery_tag=method.delivery_tag)

channel.basic_consume(queue='tasks', on_message_callback=callback)
channel.start_consuming()
```

## Monitoring and Logging

**View logs:**
```bash
./manage-colima.sh logs myservice -f
```

**Check metrics in Grafana:**
```bash
open http://localhost:3001
```

**Query logs in Loki:**
```logql
{container_name="dev-myservice"} |= "ERROR"
```

## Stopping Services

**End of day:**
```bash
./manage-colima.sh stop
```

**Restart specific service:**
```bash
docker compose restart postgres
```

## Related Pages

- [CLI-Reference](CLI-Reference)
- [Service-Configuration](Service-Configuration)
- [Forgejo-Setup](Forgejo-Setup)
