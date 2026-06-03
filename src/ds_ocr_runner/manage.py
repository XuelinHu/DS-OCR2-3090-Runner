import argparse

from ds_ocr_runner.db import create_all


def main() -> None:
    parser = argparse.ArgumentParser(description="DS-OCR2 runner management commands")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("init-db", help="Create database tables")
    args = parser.parse_args()

    if args.command == "init-db":
        create_all()
        print("database tables created")


if __name__ == "__main__":
    main()

