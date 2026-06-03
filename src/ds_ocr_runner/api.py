from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from ds_ocr_runner.config import Settings, get_settings
from ds_ocr_runner.db import get_db
from ds_ocr_runner.models import FileRecord, OcrTask, new_id
from ds_ocr_runner.schemas import (
    ClaimTaskRequest,
    CompleteTaskRequest,
    CreateTaskRequest,
    FailTaskRequest,
    FileOut,
    ResultOut,
    TaskOut,
)
from ds_ocr_runner.services import (
    cancel_task,
    claim_next_task,
    complete_task,
    create_file_record,
    create_task,
    fail_task,
)
from ds_ocr_runner.storage import LocalStorage

router = APIRouter()


def get_storage(settings: Settings = Depends(get_settings)) -> LocalStorage:
    return LocalStorage(settings.resolved_storage_root)


@router.get("/healthz")
def healthz(settings: Settings = Depends(get_settings)) -> dict[str, str]:
    return {"status": "ok", "app": settings.app_name, "env": settings.app_env}


@router.post("/api/files", response_model=FileOut, status_code=status.HTTP_201_CREATED)
def upload_file(
    upload: UploadFile = File(...),
    db: Session = Depends(get_db),
    storage: LocalStorage = Depends(get_storage),
) -> FileRecord:
    file_id = new_id("file")
    storage_path, size_bytes, sha256 = storage.save_upload(upload, file_id=file_id)
    return create_file_record(
        db,
        file_id=file_id,
        original_name=upload.filename or Path(storage_path).name,
        storage_path=storage_path,
        content_type=upload.content_type,
        size_bytes=size_bytes,
        sha256=sha256,
    )


@router.get("/api/files/{file_id}", response_model=FileOut)
def get_file(file_id: str, db: Session = Depends(get_db)) -> FileRecord:
    record = db.get(FileRecord, file_id)
    if record is None:
        raise HTTPException(status_code=404, detail="file not found")
    return record


@router.post("/api/ocr/tasks", response_model=TaskOut, status_code=status.HTTP_201_CREATED)
def create_ocr_task(payload: CreateTaskRequest, db: Session = Depends(get_db)) -> OcrTask:
    try:
        return create_task(
            db,
            file_id=payload.file_id,
            mode=payload.mode,
            options=payload.options,
            priority=payload.priority,
        )
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="file not found") from exc


@router.get("/api/ocr/tasks/{task_id}", response_model=TaskOut)
def get_task(task_id: str, db: Session = Depends(get_db)) -> OcrTask:
    task = db.get(OcrTask, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")
    return task


@router.post("/api/ocr/tasks/{task_id}/cancel", response_model=TaskOut)
def cancel_ocr_task(task_id: str, db: Session = Depends(get_db)) -> OcrTask:
    try:
        return cancel_task(db, task_id=task_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="task not found") from exc


@router.get("/api/ocr/tasks/{task_id}/result", response_model=ResultOut)
def get_task_result(task_id: str, db: Session = Depends(get_db)) -> ResultOut:
    task = db.get(OcrTask, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")
    if task.result is None:
        raise HTTPException(status_code=404, detail="result not found")
    return task.result


@router.post("/internal/queue/claim", response_model=TaskOut | None)
def claim_task(
    payload: ClaimTaskRequest,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> OcrTask | None:
    return claim_next_task(db, worker_id=payload.worker_id, settings=settings)


@router.post("/internal/queue/{task_id}/complete", response_model=TaskOut)
def complete_claimed_task(
    task_id: str,
    payload: CompleteTaskRequest,
    db: Session = Depends(get_db),
) -> OcrTask:
    try:
        return complete_task(
            db,
            task_id=task_id,
            text=payload.text,
            markdown=payload.markdown,
            layout=payload.layout,
            metadata=payload.metadata,
        )
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="task not found") from exc


@router.post("/internal/queue/{task_id}/fail", response_model=TaskOut)
def fail_claimed_task(
    task_id: str,
    payload: FailTaskRequest,
    db: Session = Depends(get_db),
) -> OcrTask:
    try:
        return fail_task(
            db,
            task_id=task_id,
            error_message=payload.error_message,
            retryable=payload.retryable,
        )
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="task not found") from exc
