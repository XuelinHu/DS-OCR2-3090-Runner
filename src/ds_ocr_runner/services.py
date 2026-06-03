from datetime import UTC, datetime, timedelta

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from ds_ocr_runner.config import Settings
from ds_ocr_runner.models import FileRecord, OcrResult, OcrTask, TaskStatus, utc_now


def create_file_record(
    db: Session,
    *,
    file_id: str,
    original_name: str,
    storage_path: str,
    content_type: str | None,
    size_bytes: int,
    sha256: str,
) -> FileRecord:
    record = FileRecord(
        id=file_id,
        original_name=original_name,
        storage_path=storage_path,
        content_type=content_type,
        size_bytes=size_bytes,
        sha256=sha256,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


def create_task(
    db: Session,
    *,
    file_id: str,
    mode: str,
    options: dict,
    priority: int,
) -> OcrTask:
    file_record = db.get(FileRecord, file_id)
    if file_record is None:
        raise KeyError(file_id)

    task = OcrTask(file_id=file_id, mode=mode, options=options, priority=priority)
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


def claim_next_task(db: Session, *, worker_id: str, settings: Settings) -> OcrTask | None:
    now = utc_now()
    stale_before = now - timedelta(seconds=settings.queue_visibility_timeout_seconds)

    stmt = (
        select(OcrTask)
        .where(
            OcrTask.status.in_([TaskStatus.queued, TaskStatus.running]),
            OcrTask.attempts < OcrTask.max_attempts,
            or_(OcrTask.status == TaskStatus.queued, OcrTask.locked_at < stale_before),
        )
        .order_by(OcrTask.priority.asc(), OcrTask.created_at.asc())
        .with_for_update(skip_locked=True)
        .limit(1)
    )

    with db.begin():
        task = db.execute(stmt).scalar_one_or_none()
        if task is None:
            return None
        task.status = TaskStatus.running
        task.worker_id = worker_id
        task.locked_at = now
        task.started_at = task.started_at or now
        task.attempts += 1
        db.add(task)

    db.refresh(task)
    return task


def complete_task(
    db: Session,
    *,
    task_id: str,
    text: str,
    markdown: str,
    layout: dict,
    metadata: dict,
) -> OcrTask:
    task = db.get(OcrTask, task_id)
    if task is None:
        raise KeyError(task_id)
    if task.status == TaskStatus.canceled:
        return task

    result = task.result or OcrResult(task_id=task.id)
    result.text = text
    result.markdown = markdown
    result.layout = layout
    result.metadata_json = metadata

    task.status = TaskStatus.succeeded
    task.completed_at = datetime.now(UTC)
    task.error_message = None

    db.add(result)
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


def fail_task(db: Session, *, task_id: str, error_message: str, retryable: bool) -> OcrTask:
    task = db.get(OcrTask, task_id)
    if task is None:
        raise KeyError(task_id)
    if task.status == TaskStatus.canceled:
        return task

    task.error_message = error_message
    if retryable and task.attempts < task.max_attempts:
        task.status = TaskStatus.queued
        task.worker_id = None
        task.locked_at = None
    else:
        task.status = TaskStatus.failed
        task.completed_at = utc_now()

    db.add(task)
    db.commit()
    db.refresh(task)
    return task


def cancel_task(db: Session, *, task_id: str) -> OcrTask:
    task = db.get(OcrTask, task_id)
    if task is None:
        raise KeyError(task_id)
    if task.status in [TaskStatus.succeeded, TaskStatus.failed]:
        return task

    task.status = TaskStatus.canceled
    task.completed_at = utc_now()
    db.add(task)
    db.commit()
    db.refresh(task)
    return task
