import hashlib
import shutil
from pathlib import Path

from fastapi import UploadFile

from ds_ocr_runner.models import new_id


class LocalStorage:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.uploads = root / "uploads"
        self.results = root / "results"
        self.exports = root / "exports"

    def ensure(self) -> None:
        self.uploads.mkdir(parents=True, exist_ok=True)
        self.results.mkdir(parents=True, exist_ok=True)
        self.exports.mkdir(parents=True, exist_ok=True)

    def save_upload(self, upload: UploadFile, *, file_id: str) -> tuple[str, int, str]:
        self.ensure()
        safe_name = Path(upload.filename or "upload.bin").name
        target_dir = self.uploads / file_id
        target_dir.mkdir(parents=True, exist_ok=False)
        target_path = target_dir / safe_name

        sha256 = hashlib.sha256()
        size = 0
        with target_path.open("wb") as output:
            while chunk := upload.file.read(1024 * 1024):
                size += len(chunk)
                sha256.update(chunk)
                output.write(chunk)

        return str(target_path.relative_to(self.root)), size, sha256.hexdigest()

    def open_read(self, relative_path: str):
        path = (self.root / relative_path).resolve()
        if not path.is_file() or self.root.resolve() not in path.parents:
            raise FileNotFoundError(relative_path)
        return path.open("rb")

    def copy_result_artifact(self, source: Path, name: str) -> str:
        self.ensure()
        artifact_id = new_id("artifact")
        target = self.results / artifact_id / Path(name).name
        target.parent.mkdir(parents=True, exist_ok=False)
        shutil.copyfile(source, target)
        return str(target.relative_to(self.root))
