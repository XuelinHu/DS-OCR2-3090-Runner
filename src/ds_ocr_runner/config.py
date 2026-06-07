from functools import lru_cache
from pathlib import Path
from urllib.parse import quote_plus

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "DS-OCR2-3090-Runner"
    app_env: str = "local"
    database_url: str | None = None
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "dsocr"
    postgres_user: str = "dsocr"
    postgres_password: str = "dsocr"
    storage_root: Path = Field(default=Path("./storage"))
    ocr_backend: str = "stub"
    deepseek_ocr_python: str = "python"
    deepseek_ocr_model_dir: Path = Field(default=Path("./models/DeepSeek-OCR-2"))
    deepseek_ocr_output_root: Path = Field(default=Path("./storage/results/deepseek-ocr-2"))
    deepseek_ocr_timeout_seconds: int = 900
    deepseek_ocr_base_size: int = 1024
    deepseek_ocr_image_size: int = 768
    deepseek_ocr_crop_mode: bool = True
    deepseek_ocr_attn_implementation: str = "eager"
    deepseek_ocr_dtype: str = "bfloat16"
    queue_visibility_timeout_seconds: int = 900
    worker_id: str = "local-worker"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    @property
    def resolved_storage_root(self) -> Path:
        return self.storage_root.expanduser().resolve()

    @property
    def resolved_deepseek_ocr_model_dir(self) -> Path:
        return self.deepseek_ocr_model_dir.expanduser().resolve()

    @property
    def resolved_deepseek_ocr_output_root(self) -> Path:
        return self.deepseek_ocr_output_root.expanduser().resolve()

    @property
    def sqlalchemy_database_url(self) -> str:
        if self.database_url:
            return self.database_url

        user = quote_plus(self.postgres_user)
        password = quote_plus(self.postgres_password)
        db_name = quote_plus(self.postgres_db)
        return (
            f"postgresql+psycopg://{user}:{password}"
            f"@{self.postgres_host}:{self.postgres_port}/{db_name}"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
