# FAQ

**Q: Can I use this on Intel Mac?**
A: Yes, but change VM type:
```bash
export COLIMA_CPU=4
export COLIMA_MEMORY=8
colima start --vm-type qemu  # Instead of vz
```

**Q: Can I run multiple Colima instances?**
A: Yes, use profiles:
```bash
export COLIMA_PROFILE=project1
./manage-colima.sh start

export COLIMA_PROFILE=project2
./manage-colima.sh start
```

**Q: How do I access services from UTM VM?**
A: Use Colima IP instead of localhost:
```bash
COLIMA_IP=$(./manage-colima.sh ip | grep "Colima IP:" | awk '{print $3}')
psql -h $COLIMA_IP -p 5432 -U $POSTGRES_USER
```

**Q: Can I use Docker Desktop instead of Colima?**
A: Yes, but remove `colima` commands from `manage-colima.sh`. Just use `docker compose up -d`.

**Q: How do I update service versions?**
A: Edit `docker-compose.yml`:
```yaml
# Change
image: postgres:16-alpine

# To
image: postgres:17-alpine

# Then
docker compose pull postgres
docker compose up -d postgres
```

**Q: What if I lose Vault unseal keys?**
A: Data is permanently inaccessible. You must:
1. Stop Vault
2. Delete vault_data volume
3. Re-initialize (creates new keys)
4. Re-enter all secrets

**ALWAYS BACKUP UNSEAL KEYS!**

**Q: Can I use this for production?**
A: No. Requires:
- TLS everywhere
- External secrets management
- High availability
- Monitoring/alerting
- Proper backup strategy
- Security hardening

**Q: How do I migrate data from old setup?**
A:
1. Backup old databases (pg_dump, mysqldump, etc.)
2. Start Colima services
3. Restore backups
4. Test connectivity
5. Update application connection strings

**Q: Redis cluster vs single instance?**
A: Cluster provides:
- Horizontal scaling (distribute data)
- High availability (node failures)
- Production parity

Single instance is simpler but doesn't match production.

