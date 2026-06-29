"""Open Campus backend — FastAPI app entrypoint.

Mounts the auth, transparency, and student routers; exposes /health and
/disclaimer. Runs a background sweeper to evict expired UCAM sessions and closes
all sessions on shutdown. Stateless: no database.
"""
from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import auth, calendar as calendar_api, settings as settings_api, student
from app.auth import session_store
from app.config import settings

logging.basicConfig(level=logging.INFO if not settings.debug else logging.DEBUG)

DISCLAIMER = (
    "Open Campus is an independent, unofficial, open-source project. It is NOT "
    "affiliated with, endorsed by, or connected to United International University "
    "(UIU) or Edusoft Consultants Ltd. It accesses only the data a student can "
    "already see in their own UCAM account, using that student's own credentials. "
    "The server is stateless: your UCAM password and your data are never stored — "
    "everything is fetched live and forgotten."
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Fail-closed on unsafe production config (placeholder secret, "*" CORS, etc.).
    settings.require_production_safety()
    sweeper = asyncio.create_task(session_store.run_sweeper())
    try:
        yield
    finally:
        sweeper.cancel()
        await session_store.close_all()


app = FastAPI(
    title="Open Campus API",
    version="0.1.0",
    description="Unofficial companion API for UIU's UCAM portal. " + DISCLAIMER,
    lifespan=lifespan,
)

# CORS: a native Flutter app needs none. Only enable for a browser/web build, with
# an explicit origin allow-list — never "*" with credentials. Since we authenticate
# via a Bearer header (not cookies), credentials are off.
if settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(auth.router)
app.include_router(settings_api.router)
app.include_router(student.router)
app.include_router(calendar_api.router)


@app.get("/health", tags=["meta"])
async def health() -> dict:
    return {"status": "ok"}


@app.get("/disclaimer", tags=["meta"])
async def disclaimer() -> dict:
    return {"disclaimer": DISCLAIMER}
