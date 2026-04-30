# Windows, IIS and MSSQL deployment

This branch keeps the Django/React application close to upstream, but makes the runtime configurable for Microsoft SQL Server and IIS.

## Architecture

- IIS serves the built React frontend from `frontend/dist`.
- IIS URL Rewrite and ARR proxy `/api`, `/admin`, `/media`, `/static`, and `/ws` to the local ASGI backend.
- The backend runs as a Windows service or scheduled process with Daphne on `127.0.0.1:8181`.
- SQL Server is accessed through `mssql-django` and Microsoft's ODBC Driver 18.
- Docker administration is disabled with `DOCKER_FEATURE_ENABLED=0`.
- Redis can be disabled with `USE_REDIS=0`. Use Redis for multi-process WebSocket deployments.

## Prerequisites

Install these on the Windows server:

- Python 3.12 or newer
- Node.js LTS
- Microsoft ODBC Driver 18 for SQL Server
- IIS with URL Rewrite and Application Request Routing
- A SQL Server database and login for ScoreCore

## Backend setup

```powershell
cd C:\scorecore\app
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item django.windows.env.example django.env
notepad django.env
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py collectstatic --noinput
.\.venv\Scripts\python.exe manage.py createadmin
.\deploy\windows\start-backend.ps1 -ProjectRoot C:\scorecore\app -Port 8181
```

For production, run `deploy/windows/start-backend.ps1` through a service wrapper such as NSSM or your standard Windows service tooling.

## Frontend setup

```powershell
cd C:\scorecore\app\frontend
Copy-Item .env.windows.example .env.production
notepad .env.production
npm install
npm run build
```

Point the IIS site root at `C:\scorecore\app\frontend\dist` and copy `deploy/windows/frontend.web.config` into that folder as `web.config`.

Build from a local NTFS path such as `C:\scorecore` or `D:\scorecore`. Native npm binaries such as `esbuild.exe` can hang or fail on mapped/network-style drives depending on Windows policy and antivirus settings.

`frontend.web.config` needs IIS URL Rewrite and ARR for the reverse proxy rules. Use `frontend.static.web.config` as `web.config` for a static-only smoke test before those modules are installed.

## SQL Server configuration

Use `django.windows.env.example` as the starting point. The important values are:

```text
DB_ENGINE=mssql
MSSQL_HOST=localhost
MSSQL_PORT=1433
MSSQL_DATABASE=scorecore
MSSQL_USER=scorecore_user
MSSQL_PASSWORD=...
MSSQL_DRIVER=ODBC Driver 18 for SQL Server
```

The default `MSSQL_EXTRA_PARAMS=TrustServerCertificate=yes;` is convenient for internal/test deployments. Use a properly trusted certificate for production when possible.

## Data migration from an existing instance

Recommended path:

1. Stop writes on the old instance.
2. Copy the complete `media` directory to the Windows server.
3. Export data from the old Django instance:

   ```bash
   python manage.py dumpdata --natural-foreign --natural-primary --exclude contenttypes --exclude auth.permission --indent 2 > scorecore-data.json
   ```

4. Run migrations on the new MSSQL database.
5. Import into the new instance:

   ```powershell
   .\.venv\Scripts\python.exe manage.py loaddata scorecore-data.json
   ```

If the source instance has very large tables, prefer a dedicated migration script that streams records model by model.

## Notes

- The built-in PostgreSQL backup/restore action is disabled on MSSQL until a SQL Server backup/export implementation is added.
- The Docker status page is hidden when `REACT_APP_DOCKER_ENABLED=0` and the backend route is disabled when `DOCKER_FEATURE_ENABLED=0`.
- Keep `origin` pointed at upstream and `fork` pointed at your fork so upstream changes can still be merged.
