import argparse
import json
import os
from pathlib import Path

import torch
from transformers import AutoModel, AutoTokenizer


DEFAULT_PROMPTS = {
    "document_markdown": "<image>\n<|grounding|>Convert the document to markdown. ",
    "plain_text": "<image>\nFree OCR. ",
    "free_ocr": "<image>\nFree OCR. ",
}
RESULT_PREFIX = "__DS_OCR_RESULT__="


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run DeepSeek-OCR-2 inference on one image.")
    parser.add_argument("--model-dir", default="models/DeepSeek-OCR-2")
    parser.add_argument("--image", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--mode", default="document_markdown")
    parser.add_argument("--prompt", default="")
    parser.add_argument("--base-size", type=int, default=1024)
    parser.add_argument("--image-size", type=int, default=768)
    parser.add_argument("--crop-mode", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--attn-implementation", default="eager")
    parser.add_argument("--dtype", choices=["bfloat16", "float16"], default="bfloat16")
    return parser.parse_args()


def dtype_from_name(name: str) -> torch.dtype:
    if name == "float16":
        return torch.float16
    return torch.bfloat16


def read_result(output_dir: Path, fallback: str | None) -> str:
    result_file = output_dir / "result.mmd"
    if result_file.is_file():
        return result_file.read_text(encoding="utf-8")
    return fallback or ""


def main() -> None:
    args = parse_args()
    model_dir = Path(args.model_dir).expanduser().resolve()
    image_path = Path(args.image).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    prompt = args.prompt or DEFAULT_PROMPTS.get(args.mode, DEFAULT_PROMPTS["document_markdown"])
    dtype = dtype_from_name(args.dtype)

    os.environ.setdefault("CUDA_VISIBLE_DEVICES", "0")
    torch.backends.cuda.matmul.allow_tf32 = True

    tokenizer = AutoTokenizer.from_pretrained(
        model_dir,
        trust_remote_code=True,
        local_files_only=True,
    )
    model = AutoModel.from_pretrained(
        model_dir,
        _attn_implementation=args.attn_implementation,
        trust_remote_code=True,
        use_safetensors=True,
        torch_dtype=dtype,
        local_files_only=True,
    )
    model = model.eval().cuda().to(dtype)

    try:
        returned = model.infer(
            tokenizer,
            prompt=prompt,
            image_file=str(image_path),
            output_path=str(output_dir),
            base_size=args.base_size,
            image_size=args.image_size,
            crop_mode=args.crop_mode,
            save_results=True,
        )
        markdown = read_result(output_dir, returned)
        payload = {
            "markdown": markdown,
            "text": markdown,
            "output_dir": str(output_dir),
            "mode": args.mode,
            "model_dir": str(model_dir),
            "image": str(image_path),
        }
        print(f"{RESULT_PREFIX}{json.dumps(payload, ensure_ascii=False)}", flush=True)
    finally:
        del model
        if torch.cuda.is_available():
            torch.cuda.empty_cache()


if __name__ == "__main__":
    main()
