# Best Practices

**Daily Usage:**
1. Start services in morning: `./manage-colima.sh start`
2. Work on projects
3. Leave running overnight (or stop: `./manage-colima.sh stop`)
4. Weekly: Check resource usage and backup

**Development Workflow:**
```bash
# 1. Make code changes
# 2. Commit to local Forgejo
git push forgejo main

# 3. Test with local databases
psql -h localhost -U $POSTGRES_USER

# 4. Store secrets in Vault
vault kv put secret/myapp/config api_key=xyz

# 5. Test message queues
# Publish to RabbitMQ, verify consumption
```

**Resource Management:**
```bash
# Check resource usage weekly
./manage-colima.sh status

# Clean up unused containers/images monthly
docker system prune -a

# Monitor disk usage
docker system df
```

**Backup Strategy:**
```bash
# Daily: Git commits (auto-backed up by Forgejo)
# Weekly: Full backup
./manage-colima.sh backup

# Store backups offsite
# Keep 4 weekly backups, 3 monthly backups
```

**Security Hygiene:**
```bash
# 1. Use strong, unique passwords in .env
# 2. Backup Vault keys securely
tar czf vault-keys.tar.gz ~/.config/vault/
gpg -c vault-keys.tar.gz  # Encrypt

# 3. Never commit secrets to Git
# 4. Rotate passwords quarterly
# 5. Update images regularly
docker compose pull
docker compose up -d
```

## Integration Patterns

**Using PostgreSQL from Your App:**
```python
# Python example
import psycopg2

conn = psycopg2.connect(
    host="localhost",
    port=5432,
    user="dev_admin",
    password="<from .env>",
    database="dev_database"
)
```

**Using Redis Cluster from Your App:**
```python
# Python with redis-py-cluster
from rediscluster import RedisCluster

startup_nodes = [
    {"host": "localhost", "port": "6379"},
    {"host": "localhost", "port": "6380"},
    {"host": "localhost", "port": "6381"}
]

rc = RedisCluster(
    startup_nodes=startup_nodes,
    password="<from .env>",
    decode_responses=True
)

rc.set("key", "value")
print(rc.get("key"))
```

**Using Vault from Your App:**
```bash
# Get secrets via CLI
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(cat ~/.config/vault/root-token)

# Store secret
vault kv put secret/myapp/db password=xyz

# Retrieve in script
DB_PASSWORD=$(vault kv get -field=password secret/myapp/db)
```

**Using RabbitMQ:**
```python
# Python with pika
import pika

credentials = pika.PlainCredentials('dev_admin', '<from .env>')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', 5672, 'dev_vhost', credentials)
)
channel = connection.channel()

channel.queue_declare(queue='hello')
channel.basic_publish(exchange='', routing_key='hello', body='Hello World!')
```

**Git with Forgejo:**
```bash
# Add Forgejo as remote
git remote add forgejo http://localhost:3000/username/repo.git

# Push
git push forgejo main

# Use SSH for better security
git remote set-url forgejo ssh://git@localhost:2222/username/repo.git
```

**Multi-Service Application Example:**
```
Your VoIP App
├── PostgreSQL: Call records, user accounts
├── Redis Cluster: Session storage, rate limiting
├── RabbitMQ: Call events, webhooks
├── MongoDB: Call logs, CDRs
├── Vault: API keys, SIP credentials
└── Forgejo: Source code, deployment scripts
```

