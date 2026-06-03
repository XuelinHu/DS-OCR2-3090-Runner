CREATE TYPE task_status AS ENUM (
    'queued',
    'running',
    'succeeded',
    'failed',
    'canceled'
);

CREATE TABLE IF NOT EXISTS ocr_files (
    id VARCHAR(64) PRIMARY KEY,
    original_name VARCHAR(255) NOT NULL,
    storage_path VARCHAR(1024) NOT NULL,
    content_type VARCHAR(255),
    size_bytes INTEGER NOT NULL,
    sha256 VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_ocr_files_sha256
    ON ocr_files (sha256);

CREATE TABLE IF NOT EXISTS ocr_tasks (
    id VARCHAR(64) PRIMARY KEY,
    file_id VARCHAR(64) NOT NULL REFERENCES ocr_files(id),
    mode VARCHAR(64) NOT NULL DEFAULT 'document_markdown',
    status task_status NOT NULL DEFAULT 'queued',
    options JSONB NOT NULL DEFAULT '{}'::jsonb,
    priority INTEGER NOT NULL DEFAULT 100,
    attempts INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 3,
    worker_id VARCHAR(128),
    locked_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_ocr_tasks_file_id
    ON ocr_tasks (file_id);

CREATE INDEX IF NOT EXISTS ix_ocr_tasks_status
    ON ocr_tasks (status);

CREATE INDEX IF NOT EXISTS ix_ocr_tasks_created_at
    ON ocr_tasks (created_at);

CREATE INDEX IF NOT EXISTS ix_ocr_tasks_queue_claim
    ON ocr_tasks (status, priority, created_at);

CREATE TABLE IF NOT EXISTS ocr_results (
    id VARCHAR(64) PRIMARY KEY,
    task_id VARCHAR(64) NOT NULL UNIQUE REFERENCES ocr_tasks(id),
    text TEXT NOT NULL DEFAULT '',
    markdown TEXT NOT NULL DEFAULT '',
    layout JSONB NOT NULL DEFAULT '{}'::jsonb,
    metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

