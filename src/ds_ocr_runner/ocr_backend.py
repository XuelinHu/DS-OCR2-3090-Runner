from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

from ds_ocr_runner.models import OcrTask


@dataclass(frozen=True)
class OcrOutput:
    text: str
    markdown: str
    layout: dict
    metadata: dict


class OcrBackend(Protocol):
    def infer(self, *, task: OcrTask, input_path: Path) -> OcrOutput:
        ...


class StubOcrBackend:
    def infer(self, *, task: OcrTask, input_path: Path) -> OcrOutput:
        message = (
            "OCR inference is disabled because OCR_BACKEND=stub. "
            "Configure a DeepSeek-OCR-2 backend on a GPU host before production use."
        )
        return OcrOutput(
            text=message,
            markdown=f"# OCR Stub Result\n\n{message}\n\nInput: `{input_path.name}`\n",
            layout={},
            metadata={"backend": "stub", "mode": task.mode},
        )


def build_ocr_backend(name: str) -> OcrBackend:
    normalized = name.strip().lower()
    if normalized == "stub":
        return StubOcrBackend()
    if normalized in {"deepseek", "deepseek-ocr-2", "deepseek_ocr_2"}:
        raise RuntimeError(
            "DeepSeek-OCR-2 backend is intentionally not auto-loaded here. "
            "Add the GPU implementation in a separate module and enable it only on OCR workers."
        )
    raise ValueError(f"Unsupported OCR_BACKEND: {name}")

