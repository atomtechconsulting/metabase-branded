# Metabase Atomtech

Custom-branded Metabase (OSS) with Atomtech logo. Ships only the Metabase app — the **PostgreSQL backing database is provisioned and managed separately** (Coolify resource, RDS, managed Postgres, etc.).

## Quick Start

You need **Docker**, **Docker Compose**, and a reachable **PostgreSQL 12+** instance with an empty database that `MB_DB_USER` can write to.

```bash
# 1. Clone the repo
git clone git@github.com:atomtechconsulting/metabase-branded.git
cd metabase-branded

# 2. Copy and edit environment variables
cp .env.example .env
# Edit .env with your external DB connection + secure secrets (see "Generate Secrets")

# 3. Build and start
docker compose up --build -d

# 4. Wait for startup (60-90s on first run while Metabase migrates the schema)
docker compose logs -f metabase
```

Once healthy, open **http://localhost:3001** and complete the setup wizard.

## Generate Secrets

```bash
# Database password (set the same value on the external Postgres)
openssl rand -hex 16

# Encryption key (CRITICAL — back this up separately!)
openssl rand -hex 32
```

## Environment Variables

| Variable | Description |
|---|---|
| `MB_DB_HOST` | Hostname of the external PostgreSQL server |
| `MB_DB_PORT` | PostgreSQL port (default `5432`) |
| `MB_DB_DBNAME` | Database name (default `metabase`) |
| `MB_DB_USER` | PostgreSQL username with rights on `MB_DB_DBNAME` |
| `MB_DB_PASS` | PostgreSQL password |
| `MB_SITE_URL` | Public URL (for email links and embeds) |
| `MB_ENCRYPTION_SECRET_KEY` | Encrypts stored DB credentials in Metabase |

## Provisioning the external database

Metabase needs an empty database and a user that owns it. On the external Postgres:

```sql
CREATE USER metabase WITH PASSWORD '<MB_DB_PASS>';
CREATE DATABASE metabase OWNER metabase;
```

In Coolify, create a **PostgreSQL** resource and attach it to the same project/network as this app so the Metabase container can reach it via the resource's internal hostname (use that hostname as `MB_DB_HOST`).

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

The application database lives in the external Postgres — back it up with whatever procedure that resource provides (Coolify's scheduled backups, `pg_dump`, managed snapshots, etc.). Example:

```bash
PGPASSWORD="$MB_DB_PASS" pg_dump \
  -h "$MB_DB_HOST" -p "$MB_DB_PORT" -U "$MB_DB_USER" "$MB_DB_DBNAME" \
  > metabase-backup-$(date +%Y%m%d).sql
```

**CRITICAL**: Also back up your `MB_ENCRYPTION_SECRET_KEY` from `.env`. Without it, all saved data source connections in Metabase are **permanently irrecoverable**, even with a full DB dump.

### Restore

```bash
docker compose stop metabase

PGPASSWORD="$MB_DB_PASS" psql \
  -h "$MB_DB_HOST" -p "$MB_DB_PORT" -U "$MB_DB_USER" "$MB_DB_DBNAME" \
  < metabase-backup-YYYYMMDD.sql

docker compose start metabase
```

## Troubleshooting

**Metabase won't start / health check fails:**
- First run takes 60-90s for DB schema init. Check logs: `docker compose logs -f metabase`
- Confirm the container can resolve `MB_DB_HOST` and reach `MB_DB_PORT`

**Logo not showing / still Metabase logo:**
- Rebuild: `docker compose build --no-cache`
- If build fails with "not found in metabase.jar", the JAR paths changed in the new version. Check: `docker run --rm metabase/metabase:vX.X.X sh -c "unzip -l /app/metabase.jar | grep logo"`

**Out of memory:**
- Increase memory limit in `docker-compose.yml` under `deploy.resources.limits.memory`
- Increase JVM heap: change `JAVA_OPTS: "-Xmx1g"` to `-Xmx2g`

**Database connection refused / authentication failed:**
- From the host: `psql "host=$MB_DB_HOST port=$MB_DB_PORT user=$MB_DB_USER dbname=$MB_DB_DBNAME"`
- In Coolify, verify the Postgres resource and the Metabase app are on the same internal network
- Check the Postgres `pg_hba.conf` allows connections from the app subnet

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
├── .env              # Secrets + external DB connection (gitignored)
├── .env.example      # Template
└── .gitignore
```

The PostgreSQL backing database is **not** part of this repo — provision it as a separate Coolify resource (or any managed Postgres) and point `MB_DB_HOST` at it.

## License

Metabase OSS is licensed under AGPL-3.0. This customization is for internal Atomtech use only.
