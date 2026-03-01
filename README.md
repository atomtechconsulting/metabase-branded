# Metabase Atomtech

Custom-branded Metabase (OSS) with Atomtech logo, running on Docker with PostgreSQL.

## Quick Start

```bash
# 1. Copy and edit environment variables
cp .env.example .env
# Edit .env with secure values (see "Generate Secrets" below)

# 2. Build and start
docker compose up --build -d

# 3. Wait for startup (60-90s on first run)
docker compose logs -f metabase
```

Once healthy, open **http://localhost:3001** and complete the setup wizard.

## Generate Secrets

```bash
# Database password
openssl rand -hex 16

# Encryption key (CRITICAL — back this up separately!)
openssl rand -hex 32
```

## Environment Variables

| Variable | Description |
|---|---|
| `MB_DB_USER` | PostgreSQL username |
| `MB_DB_PASS` | PostgreSQL password |
| `MB_SITE_URL` | Public URL (for email links and embeds) |
| `MB_ENCRYPTION_SECRET_KEY` | Encrypts stored DB credentials in Metabase |

## Upgrade Metabase Version

Dependabot checks weekly for new Metabase images and opens a PR automatically.

### When Dependabot opens a PR (build passes)

Patches still work with the new version. Merge and deploy:

```bash
docker compose up --build -d
```

Run the smoke test below to confirm branding.

### When Dependabot opens a PR (build fails)

The grep verification in `patch-branding.sh` caught a breaking change. Fix manually:

1. Inspect the new JS bundle structure:
   ```bash
   docker run --rm metabase/metabase:vX.X.X sh -c \
     "unzip -l /app/metabase.jar | grep -E 'app-(public|embed|main).*\.(js|css)'"
   ```
2. Extract the badge code to find new minified variable names:
   ```bash
   docker run --rm metabase/metabase:vX.X.X sh -c \
     "unzip -p /app/metabase.jar 'frontend_client/app/dist/app-public.*.js'" \
     | grep -oE '.{100}powered_by_metabase.{100}'
   ```
3. Update the sed patterns in `patch-branding.sh` to match the new variable names
4. Get the new image digest:
   ```bash
   docker pull metabase/metabase:vX.X.X
   docker inspect --format='{{index .RepoDigests 0}}' metabase/metabase:vX.X.X
   ```
5. Update `Dockerfile` with the new digest
6. Build and test:
   ```bash
   docker compose build --no-cache
   docker compose up -d
   ```
7. Run the smoke test below

## Verify Branding (Smoke Test)

```bash
# Wait for health check
until curl -sf http://localhost:3001/api/health; do sleep 5; done

# Check logo is Atomtech's
curl -s http://localhost:3001/app/assets/img/logo.svg | head -1

# Check favicon is served
curl -sI http://localhost:3001/favicon.ico | grep "200 OK"
```

## Backup & Restore

### Backup

```bash
# Database dump
docker exec metabase-atomtech-metabase-db-1 \
  pg_dump -U metabase metabase > metabase-backup-$(date +%Y%m%d).sql
```

**CRITICAL**: Also back up your `MB_ENCRYPTION_SECRET_KEY` from `.env`. Without it, all saved data source connections in Metabase are **permanently irrecoverable**.

### Restore

```bash
# Stop Metabase (keep DB running)
docker compose stop metabase

# Restore database
cat metabase-backup-YYYYMMDD.sql | \
  docker exec -i metabase-atomtech-metabase-db-1 psql -U metabase metabase

# Start Metabase
docker compose start metabase
```

## Troubleshooting

**Metabase won't start / health check fails:**
- First run takes 60-90s for DB schema init. Check logs: `docker compose logs -f metabase`
- Verify PostgreSQL is healthy: `docker compose ps`

**Logo not showing / still Metabase logo:**
- Rebuild: `docker compose build --no-cache`
- If build fails with "not found in metabase.jar", the JAR paths changed in the new version. Check: `docker run --rm metabase/metabase:vX.X.X sh -c "unzip -l /app/metabase.jar | grep logo"`

**Out of memory:**
- Increase memory limit in `docker-compose.yml` under `deploy.resources.limits.memory`
- Increase JVM heap: change `JAVA_OPTS: "-Xmx1g"` to `-Xmx2g`

**Database connection refused:**
- Ensure `metabase-db` container is healthy: `docker compose ps`
- Check DB logs: `docker compose logs metabase-db`

## Known Limitations (OSS)

- Email notifications show Metabase logo (not Atomtech) — cannot change without source recompilation
- `MB_APPLICATION_NAME` is Pro/Enterprise only — `MB_SITE_NAME` provides partial coverage
- Custom colors, fonts, and login page text require Pro/Enterprise license

## Architecture

```
metabase-atomtech/
├── assets/           # Branding files baked into metabase.jar at build time
│   ├── logo.svg              # White Atomtech logo (SVG with embedded PNG)
│   ├── favicon.ico           # Browser tab icon
│   ├── favicon-16x16.png     # Small favicon
│   ├── favicon-32x32.png     # Standard favicon
│   ├── apple-touch-icon.png  # iOS bookmark icon
│   └── loading_favicon.gif   # Browser tab icon during query execution
├── Dockerfile        # JAR surgery: extracts metabase.jar, replaces assets, repacks
├── docker-compose.yml
├── .env              # Secrets (gitignored)
├── .env.example      # Template
└── .gitignore
```

## License

Metabase OSS is licensed under AGPL-3.0. This customization is for internal Atomtech use only.
