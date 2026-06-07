# DS-OCR2-3090-Runner

<p align="center">
  <img height="20" src="https://img.shields.io/badge/python-3.11%2B-3776AB" />
  <img height="20" src="https://img.shields.io/badge/fastapi-0.115%2B-009688" />
  <img height="20" src="https://img.shields.io/badge/flutter-configured-02569B" />
  <img height="20" src="https://img.shields.io/badge/dart-3.12%2B-0175C2" />
  <img height="20" src="https://img.shields.io/badge/postgresql-16-4169E1" />
  <img height="20" src="https://img.shields.io/badge/sqlalchemy-2.0%2B-D71F00" />
  <img height="20" src="https://img.shields.io/badge/docker-compose-2496ED" />
</p>

DeepSeek-OCR-2 app backend scaffold. The service uses FastAPI for HTTP APIs,
PostgreSQL as both application database and task queue, and local filesystem
storage under this repository instead of object storage.

The default OCR backend is `stub`, so this project does not load DeepSeek-OCR-2,
CUDA, PyTorch, vLLM, or any GPU process unless a real backend is added and
explicitly enabled later.

## Current Scope

- Upload source images or PDFs to local `./storage/uploads`.
- Create OCR tasks through the API.
- Claim queued tasks from PostgreSQL using `FOR UPDATE SKIP LOCKED`.
- Store task results in PostgreSQL.
- Keep file storage local to the current repository.
- Provide a safe stub worker for non-GPU development.

## Architecture

```text
Android app / web client
  -> FastAPI backend
  -> local storage: ./storage
  -> PostgreSQL tables
  -> PostgreSQL-backed queue
  -> OCR worker
  -> DeepSeek-OCR-2 backend, added later on GPU host
```

## Queue Design

Redis is intentionally not used. Workers claim tasks directly from
`ocr_tasks`:

```sql
SELECT *
FROM ocr_tasks
WHERE status IN ('queued', 'running')
ORDER BY priority ASC, created_at ASC
FOR UPDATE SKIP LOCKED
LIMIT 1;
```

The implementation also tracks `locked_at`, `worker_id`, `attempts`, and
`max_attempts` so stale running tasks can be reclaimed after the visibility
timeout.

## Local Storage

The default local storage root is:

```text
./storage
```

Runtime files are ignored by git:

```text
storage/uploads
storage/results
storage/exports
```

## API

Main endpoints:

```text
GET  /healthz
POST /api/files
GET  /api/files/{file_id}
POST /api/ocr/tasks
GET  /api/ocr/tasks/{task_id}
POST /api/ocr/tasks/{task_id}/cancel
GET  /api/ocr/tasks/{task_id}/result

POST /internal/queue/claim
POST /internal/queue/{task_id}/complete
POST /internal/queue/{task_id}/fail
```

## Local Development

Create a local env file:

```bash
cp .env.example .env
```

For the current local PostgreSQL instance, this repository also supports
component-based database settings:

```text
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=dsocr
POSTGRES_USER=...
POSTGRES_PASSWORD=...
```

Install dependencies:

```bash
python -m venv .venv
. .venv/bin/activate
pip install -e .
```

Start PostgreSQL only:

```bash
docker compose up -d postgres
```

Initialize tables:

```bash
python -m ds_ocr_runner.manage init-db
```

Start the API:

```bash
uvicorn ds_ocr_runner.main:app --reload
```

The API container is behind the `api` compose profile, so `docker compose up -d`
does not start it unless requested.

## Worker

The worker defaults to `OCR_BACKEND=stub`:

```bash
python -m ds_ocr_runner.worker --once
```

That path is safe for CPU-only development. A real DeepSeek-OCR-2 backend should
be added in a separate GPU deployment module and enabled explicitly with an
environment value such as `OCR_BACKEND=deepseek-ocr-2`.

The current GPU backend runs DeepSeek-OCR-2 through a separate Python process:

```bash
OCR_BACKEND=deepseek-ocr-2 python -m ds_ocr_runner.worker --once
```

It defaults to the local model cache at `models/DeepSeek-OCR-2` and uses
`eager` attention to avoid requiring `flash-attn`.

## Model Cache

DeepSeek-OCR-2 model files are cached under:

```text
models/DeepSeek-OCR-2
```

Prefetch command:

```bash
pip install -e ".[models]"
python scripts/prefetch_models.py
```

The script downloads files only. It defaults to `https://hf-mirror.com` and
does not import CUDA, PyTorch, vLLM, or load the model into GPU memory.

## Android Client Direction

The Flutter Android client lives under `mobile/`. Recommended stack:

- Flutter 3.44+
- Dart 3.12+
- Material 3
- `file_picker` for file import
- `http` for backend calls
- `shared_preferences` for API base URL

The client should call the public `/api/*` endpoints only. Internal queue
endpoints are for trusted backend workers.

## Badge Sources

README badges were generated from real repository files using the
`github-readme-badges` skill, then normalized for display:

- `pyproject.toml`
- `Dockerfile`
- `compose.yaml`
- `mobile/pubspec.yaml`
- `mobile/android/app/src/main/AndroidManifest.xml`
