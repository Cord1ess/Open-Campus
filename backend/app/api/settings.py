"""Transparency route.

The backend is stateless — there are no per-user settings to store and no sync
toggle, because we store nothing. This endpoint exists purely to state, in plain
language, exactly what we do and don't keep. The app surfaces this to the user.
"""
from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(prefix="/transparency", tags=["transparency"])

_WE_DO_NOT_STORE = [
    "We do NOT store your UCAM password — it's used once to log in, then discarded.",
    "We do NOT store your grades, attendance, profile, or any UCAM data on our servers.",
    "We do NOT keep a database of students or their records.",
]
_HOW_IT_WORKS = (
    "Everything is fetched live from your own UCAM account each time you view it, "
    "then shown to you and forgotten by our server. The app keeps your last view on "
    "your own device so it loads instantly; logging out clears it. Our server is "
    "stateless — it holds only your live session in memory while you're using it, "
    "and that ends when you log out or it expires."
)


class TransparencyResponse(BaseModel):
    we_do_not_store: list[str]
    how_it_works: str


@router.get("", response_model=TransparencyResponse)
async def transparency() -> TransparencyResponse:
    return TransparencyResponse(
        we_do_not_store=_WE_DO_NOT_STORE,
        how_it_works=_HOW_IT_WORKS,
    )
