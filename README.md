# ScoreCore / Scoring Tool

ScoreCore is a Django and React application for scoring image sets with multiple users. It supports project-based image review, configurable scoring features, useless-image handling, and agreement/evaluation exports for scientific workflows.

This branch is maintained for the Windows/IIS/MSSQL deployment used at FU Berlin while still keeping the original Docker/PostgreSQL workflow available for local or Linux-based setups.

## Features

- Create scoring projects from uploaded image folders.
- Assign users and configure required scores per user and per image.
- Mark unsuitable images as useless.
- Review score progress and per-project metrics.
- Export evaluation data as JSON/XLSX.
- Run with PostgreSQL/Docker or Microsoft SQL Server/IIS.

## Runtime Options

### Docker/PostgreSQL

The original deployment model uses:

- Django REST backend
- React frontend
- PostgreSQL 16
- Nginx reverse proxy
- Redis for async/WebSocket support

Use this for local Docker-based development or Linux-style deployments.

### Windows/IIS/MSSQL

The `windows-iis-mssql` branch adds the production Windows path:

- IIS serves the built React app.
- IIS URL Rewrite and ARR proxy `/api`, `/admin`, `/media`, `/static`, and `/ws` to Daphne.
- Daphne runs the Django ASGI app on `127.0.0.1:8181`.
- The backend can run as the `ScoreCoreBackend` Windows service via NSSM.
- SQL Server is supported through `mssql-django` and ODBC Driver 18.
- Docker features can be disabled with `DOCKER_FEATURE_ENABLED=0` and `REACT_APP_DOCKER_ENABLED=0`.
- IIS upload size is raised in `deploy/windows/frontend.web.config` via `requestLimits maxAllowedContentLength`.
- Frontend builds use ASCII JS output to avoid broken emoji/symbol rendering on IIS/browser encoding edges.

Detailed setup notes live in [docs/windows-iis-mssql.md](docs/windows-iis-mssql.md).

## Local Docker Setup

### Prerequisites

- Docker
- Python
- Node.js and npm

Add local host names if you use the default Docker host setup:

```text
127.0.0.1 api.scoring.local
127.0.0.1 scoring.local
```

### Start

```sh
cp .env.template .env
cp django.env.template django.env
docker compose up -d
```

Edit `.env` and `django.env` before starting if your ports, hosts, credentials, or media paths differ.

## Local Development

### Backend

```sh
python manage.py makemigrations
python manage.py migrate
python manage.py createadmin
python manage.py runserver localhost:8000
```

### Frontend

```sh
cd frontend
npm install
npm start
```

## Windows/IIS/MSSQL Deployment

### Server Prerequisites

Install on the Windows server:

- Python 3.12 or newer
- Node.js LTS
- Microsoft ODBC Driver 18 for SQL Server
- IIS with URL Rewrite and Application Request Routing
- NSSM, if running the backend as a service
- A SQL Server database and login for ScoreCore

### Backend Environment

Copy and edit the Windows environment template:

```powershell
Copy-Item django.windows.env.example django.env
notepad django.env
```

Important values:

```text
DB_ENGINE=mssql
MSSQL_HOST=localhost
MSSQL_PORT=1433
MSSQL_DATABASE=scorecore
MSSQL_USER=scorecore_user
MSSQL_PASSWORD=...
MSSQL_DRIVER=ODBC Driver 18 for SQL Server
MEDIA_ROOT=C:\inetpub\scorecore\media
USE_REDIS=0
DOCKER_FEATURE_ENABLED=0
```

### Backend Setup

```powershell
cd C:\inetpub\scorecore\backend
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py collectstatic --noinput
.\.venv\Scripts\python.exe manage.py createadmin
```

Run manually for testing:

```powershell
.\deploy\windows\start-backend.ps1 -ProjectRoot C:\inetpub\scorecore\backend -Port 8181
```

Install or reinstall the Windows service:

```powershell
.\deploy\windows\install-backend-service.ps1 -ProjectRoot C:\inetpub\scorecore\backend -Reinstall
```

### Frontend and IIS

The production frontend is built with Vite. The IIS site root should point to:

```text
C:\inetpub\scorecore\frontend
```

Use `deploy/windows/frontend.web.config` as the IIS `web.config`. It contains:

- public-path routing for `/scoring/`
- API/admin/media/static/ws reverse proxy rules
- static asset MIME mappings
- upload request limit configuration for larger folder uploads

Use `deploy/windows/frontend.static.web.config` only for a static-only smoke test before ARR/URL Rewrite are configured.

### Deploy to vetweb01

From a local checkout of this branch:

```powershell
$script = Get-Content -Raw .\deploy\windows\deploy-to-vetweb01.ps1
$scriptBlock = [scriptblock]::Create($script)
& $scriptBlock -RepoRoot "H:\wirklichnurneueprojekte\scoretool\scoreCore" -PublicUrl "/scoring/"
```

The script:

- builds the frontend in `D:\scorecore-frontend-build`
- deploys the frontend to `\\vetweb01\c$\inetpub\scorecore\frontend`
- deploys backend files to `\\vetweb01\c$\inetpub\scorecore\backend`
- copies deployment and SQL scripts to `\\vetweb01\c$\inetpub\scorecore\deploy` and `sql`
- writes the IIS `web.config` with the configured public path

After backend code changes, restart the service:

```powershell
sc.exe \\vetweb01 stop ScoreCoreBackend
sc.exe \\vetweb01 start ScoreCoreBackend
```

### Useful Server Paths

```text
\\vetweb01\c$\inetpub\scorecore\frontend
\\vetweb01\c$\inetpub\scorecore\backend
\\vetweb01\c$\inetpub\scorecore\media
\\vetweb01\c$\inetpub\scorecore\logs
\\vetweb01\c$\inetpub\logs\LogFiles
```

For upload issues, check IIS first. A `413.1` status means IIS rejected the upload before Django received it.

## SQL Server Seed Scripts

SQL Server schema and seed scripts are in:

```text
deploy/sqlserver/001_create_scorecore_tables.sql
deploy/sqlserver/002_seed_scorecore.sql
```

Run `001_create_scorecore_tables.sql` first, then `002_seed_scorecore.sql`. Adjust the SQLCMD variables in the seed script before running it in a real environment.

## Data Migration

For migrating from an existing Django/PostgreSQL instance:

1. Stop writes on the old instance.
2. Copy the complete `media` directory to the Windows server.
3. Export data:

   ```sh
   python manage.py dumpdata --natural-foreign --natural-primary --exclude contenttypes --exclude auth.permission --indent 2 > scorecore-data.json
   ```

4. Run migrations on the MSSQL target.
5. Import:

   ```powershell
   .\.venv\Scripts\python.exe manage.py loaddata scorecore-data.json
   ```

For very large instances, prefer a streaming migration script model by model.

## Notes for Maintainers

- Keep `origin` pointed at upstream: `https://github.com/RedCore161/scoreCore.git`.
- Keep `fork` pointed at the Windows fork: `https://github.com/nutzlastfan/scoreCore.git`.
- The active branch for this deployment is `windows-iis-mssql`.
- Build from a local NTFS path where possible. Native npm binaries such as `esbuild.exe` can be unreliable on mapped/network-style paths.
- The frontend uses `esbuild.charset = "ascii"` in `frontend/vite.config.ts` so icons and symbols are emitted as escapes instead of raw Unicode.

## Contact

For issues or deployment notes, use the GitHub issue tracker or document the operational finding in this branch.
