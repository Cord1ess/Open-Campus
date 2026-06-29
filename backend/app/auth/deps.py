"""FastAPI dependencies for authenticating app requests via the Open Campus token."""
from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Header, HTTPException, status

from app.auth import session_store
from app.ucam.client import UcamSession


def bearer_token(
    authorization: Annotated[str | None, Header()] = None,
) -> str:
    """Extract the raw Bearer token, or 401. Used where we need the token itself
    (e.g. logout)."""
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return authorization.split(" ", 1)[1].strip()


async def current_session(
    token: Annotated[str, Depends(bearer_token)],
) -> UcamSession:
    """Resolve the Bearer token to a live UCAM session, or 401.

    A 401 here means our token is invalid/expired. A *UCAM* session expiry
    (cookies died upstream) surfaces later as UcamSessionExpired during a data
    call, which the route maps to 409 so the app can show the soft re-login
    prompt rather than a hard logout.
    """
    session = session_store.resolve(token)
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session invalid or expired; please log in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return session


CurrentSession = Annotated[UcamSession, Depends(current_session)]
BearerToken = Annotated[str, Depends(bearer_token)]
