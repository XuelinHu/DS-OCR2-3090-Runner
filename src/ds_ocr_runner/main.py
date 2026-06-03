from fastapi import FastAPI

from ds_ocr_runner.api import router
from ds_ocr_runner.config import get_settings


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name)
    app.include_router(router)
    return app


app = create_app()

