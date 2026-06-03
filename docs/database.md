# Database

The backend uses PostgreSQL for both persistence and queueing. Redis is not part
of this design.

## Local Connection

The local `.env` file is configured with component fields:

```text
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=dsocr
POSTGRES_USER=deipss
POSTGRES_PASSWORD=<local password>
```

The app builds the SQLAlchemy connection string internally, so special
characters in the password do not need manual URL escaping.

## Schema

The SQL schema is available at:

```text
sql/schema.sql
```

The Python management command can also create the same SQLAlchemy-managed
tables:

```bash
python -m ds_ocr_runner.manage init-db
```

## Queue Claim Pattern

Workers claim jobs with PostgreSQL row locks:

```sql
SELECT *
FROM ocr_tasks
WHERE status IN ('queued', 'running')
ORDER BY priority ASC, created_at ASC
FOR UPDATE SKIP LOCKED
LIMIT 1;
```

This lets multiple workers safely claim different rows without a Redis queue.
