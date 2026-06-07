from dataclasses import dataclass
import json
from pathlib import Path
import subprocess
from typing import Protocol

from ds_ocr_runner.config import get_settings
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


class ExternalDeepSeekOcr2Backend:
    result_prefix = "__DS_OCR_RESULT__="

    def infer(self, *, task: OcrTask, input_path: Path) -> OcrOutput:
        settings = get_settings()
        output_dir = settings.resolved_deepseek_ocr_output_root / task.id
        output_dir.mkdir(parents=True, exist_ok=True)

        cmd = [
            settings.deepseek_ocr_python,
            "scripts/run_deepseek_ocr2.py",
            "--model-dir",
            str(settings.resolved_deepseek_ocr_model_dir),
            "--image",
            str(input_path),
            "--output-dir",
            str(output_dir),
            "--mode",
            task.mode,
            "--base-size",
            str(settings.deepseek_ocr_base_size),
            "--image-size",
            str(settings.deepseek_ocr_image_size),
            "--attn-implementation",
            settings.deepseek_ocr_attn_implementation,
            "--dtype",
            settings.deepseek_ocr_dtype,
        ]
        cmd.append("--crop-mode" if settings.deepseek_ocr_crop_mode else "--no-crop-mode")

        completed = subprocess.run(
            cmd,
            cwd=Path(__file__).resolve().parents[2],
            text=True,
            capture_output=True,
            timeout=settings.deepseek_ocr_timeout_seconds,
            check=False,
        )
        if completed.returncode != 0:
            raise RuntimeError(
                "DeepSeek-OCR-2 inference failed\n"
                f"stdout:\n{completed.stdout}\n"
                f"stderr:\n{completed.stderr}"
            )

        payload = None
        for line in reversed(completed.stdout.splitlines()):
            if line.startswith(self.result_prefix):
                payload = json.loads(line.removeprefix(self.result_prefix))
                break
        if payload is None:
            raise RuntimeError(
                "DeepSeek-OCR-2 inference did not emit a result payload\n"
                f"stdout:\n{completed.stdout}\n"
                f"stderr:\n{completed.stderr}"
            )

        markdown = payload.get("markdown", "")
        return OcrOutput(
            text=payload.get("text", markdown),
            markdown=markdown,
            layout={},
            metadata={
                "backend": "deepseek-ocr-2",
                "mode": task.mode,
                "output_dir": payload.get("output_dir"),
                "model_dir": payload.get("model_dir"),
            },
        )


def build_ocr_backend(name: str) -> OcrBackend:
    normalized = name.strip().lower()
    if normalized == "stub":
        return StubOcrBackend()
    if normalized in {"deepseek", "deepseek-ocr-2", "deepseek_ocr_2"}:
        return ExternalDeepSeekOcr2Backend()
    raise ValueError(f"Unsupported OCR_BACKEND: {name}")
