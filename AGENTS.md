# Codex Agent Notes

<!-- codex-agent-runtime:start -->

## Runtime Ports And Database Configuration

- Keep this section aligned with the root README when database names, ports, or service defaults change.
- Do not copy secrets from local `.env` files into commits; document only placeholders or compose defaults.

### Database
- Primary database: PostgreSQL.
- Default database name: `dsocr`.
- Default host and port: `localhost:5432`; Docker Compose service name: `postgres`.
- Default Compose credentials: `POSTGRES_USER=dsocr`, `POSTGRES_PASSWORD=dsocr`; `.env.example` keeps credentials as placeholders for local override.
- SQLAlchemy URL is assembled as `postgresql+psycopg://<user>:<password>@<host>:<port>/<db>` unless `DATABASE_URL` is set.

### Default Ports
- API service: `8000` (`compose.yaml` maps `8000:8000`).
- PostgreSQL: `5432`.

### Notes For Codex Agents
- PostgreSQL is also used as the task queue through row locking; Redis is intentionally not required.
- Before committing, check `git status --short --branch` and avoid staging unrelated runtime artifacts.

### Source Files Checked
- `.env.example`
- `compose.yaml`
- `src/ds_ocr_runner/config.py`

<!-- codex-agent-runtime:end -->

## GitHub Commit Language

- Use English for all GitHub commit messages and pull/push related commit notes.
