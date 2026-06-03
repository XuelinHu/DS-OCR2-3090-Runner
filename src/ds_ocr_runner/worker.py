import argparse
import time
from pathlib import Path

from ds_ocr_runner.config import get_settings
from ds_ocr_runner.db import SessionLocal
from ds_ocr_runner.ocr_backend import build_ocr_backend
from ds_ocr_runner.services import claim_next_task, complete_task, fail_task


def run_once(worker_id: str) -> bool:
    settings = get_settings()
    backend = build_ocr_backend(settings.ocr_backend)

    with SessionLocal() as db:
        task = claim_next_task(db, worker_id=worker_id, settings=settings)
        if task is None:
            return False

        input_path = settings.resolved_storage_root / task.file.storage_path
        try:
            output = backend.infer(task=task, input_path=Path(input_path))
            complete_task(
                db,
                task_id=task.id,
                text=output.text,
                markdown=output.markdown,
                layout=output.layout,
                metadata=output.metadata,
            )
        except Exception as exc:
            fail_task(db, task_id=task.id, error_message=str(exc), retryable=True)
            raise
        return True


def main() -> None:
    settings = get_settings()
    parser = argparse.ArgumentParser(description="PostgreSQL-backed OCR worker")
    parser.add_argument("--worker-id", default=settings.worker_id)
    parser.add_argument("--poll-interval", type=float, default=2.0)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()

    while True:
        processed = run_once(args.worker_id)
        if args.once:
            return
        if not processed:
            time.sleep(args.poll_interval)


if __name__ == "__main__":
    main()
