from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from ds_ocr_runner.models import TaskStatus


class FileOut(BaseModel):
    id: str
    original_name: str
    content_type: str | None
    size_bytes: int
    sha256: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CreateTaskRequest(BaseModel):
    file_id: str
    mode: str = Field(default="document_markdown", max_length=64)
    options: dict[str, Any] = Field(default_factory=dict)
    priority: int = Field(default=100, ge=0, le=1000)


class TaskOut(BaseModel):
    id: str
    file_id: str
    mode: str
    status: TaskStatus
    options: dict[str, Any]
    priority: int
    attempts: int
    max_attempts: int
    worker_id: str | None
    error_message: str | None
    created_at: datetime
    updated_at: datetime
    started_at: datetime | None
    completed_at: datetime | None

    model_config = ConfigDict(from_attributes=True)


class ResultOut(BaseModel):
    id: str
    task_id: str
    text: str
    markdown: str
    layout: dict[str, Any]
    metadata_json: dict[str, Any]
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ClaimTaskRequest(BaseModel):
    worker_id: str = Field(min_length=1, max_length=128)


class CompleteTaskRequest(BaseModel):
    text: str = ""
    markdown: str = ""
    layout: dict[str, Any] = Field(default_factory=dict)
    metadata: dict[str, Any] = Field(default_factory=dict)


class FailTaskRequest(BaseModel):
    error_message: str
    retryable: bool = True

