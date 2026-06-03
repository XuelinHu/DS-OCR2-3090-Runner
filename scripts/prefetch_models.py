import argparse
import os
from pathlib import Path

from huggingface_hub import HfApi, snapshot_download


DEFAULT_REPO_ID = "deepseek-ai/DeepSeek-OCR-2"
DEFAULT_REVISION = "aaa02f3811945a91062062994c5c4a3f4c0af2b0"
DEFAULT_ENDPOINT = "https://hf-mirror.com"
DEFAULT_LOCAL_DIR = Path("models") / "DeepSeek-OCR-2"
PROXY_ENV_KEYS = (
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "ALL_PROXY",
    "http_proxy",
    "https_proxy",
    "all_proxy",
)


def disable_proxy_env() -> None:
    for key in PROXY_ENV_KEYS:
        os.environ.pop(key, None)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Cache model snapshots without loading GPU code.")
    parser.add_argument("--repo-id", default=DEFAULT_REPO_ID)
    parser.add_argument("--revision", default=DEFAULT_REVISION)
    parser.add_argument("--endpoint", default=DEFAULT_ENDPOINT)
    parser.add_argument("--local-dir", default=str(DEFAULT_LOCAL_DIR))
    parser.add_argument("--max-workers", type=int, default=4)
    parser.add_argument("--keep-proxy", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if not args.keep_proxy:
        disable_proxy_env()

    local_dir = Path(args.local_dir).expanduser().resolve()
    local_dir.parent.mkdir(parents=True, exist_ok=True)

    api = HfApi(endpoint=args.endpoint)
    info = api.model_info(args.repo_id, revision=args.revision)
    print(f"repo: {info.id}")
    print(f"revision: {info.sha}")
    print(f"files: {len(info.siblings)}")
    print(f"target: {local_dir}")

    if args.dry_run:
        return

    path = snapshot_download(
        repo_id=args.repo_id,
        revision=args.revision,
        endpoint=args.endpoint,
        local_dir=local_dir,
        max_workers=args.max_workers,
    )
    print(f"cached: {path}")


if __name__ == "__main__":
    main()
