"""Auth routes: login / logout / me.

Login takes the student's UCAM credentials, performs the UCAM login server-side,
stores the live session, and returns OUR JWT. The password is never stored.
"""
from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, Request, Response, status
from pydantic import BaseModel, Field

from app.auth import session_store
from app.auth.deps import BearerToken, CurrentSession
from app.auth.rate_limit import login_limiter
from app.ucam import client as ucam

router = APIRouter(prefix="/auth", tags=["auth"])
log = logging.getLogger("open_campus.auth")


def _client_ip(request: Request) -> str:
    """Best-effort client IP for rate limiting. Honors X-Forwarded-For (first
    hop) when present — set by a reverse proxy — else the direct peer."""
    xff = request.headers.get("x-forwarded-for")
    if xff:
        return xff.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


class LoginRequest(BaseModel):
    # Bounded to limit abuse; never logged.
    student_id: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=1, max_length=256)


class LoginResponse(BaseModel):
    token: str
    roll: str


class MeResponse(BaseModel):
    roll: str


@router.post("/login", response_model=LoginResponse)
async def login(body: LoginRequest, request: Request) -> LoginResponse:
    # Brute-force guard: cap login attempts per client IP.
    ip = _client_ip(request)
    if not login_limiter.check(ip):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many login attempts. Please wait a few minutes and try again.",
            headers={"Retry-After": str(login_limiter.retry_after(ip))},
        )
    try:
        ucam_session = await ucam.login(body.student_id, body.password)
    except ucam.UcamLoginError:
        # Bad credentials — safe, generic message (no internal detail).
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid student ID or password.",
        )
    except ucam.UcamError as exc:
        # Upstream/transport problem (UCAM unreachable, layout changed).
        # Log details server-side; return a generic message to the client.
        log.warning("UCAM login upstream error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Couldn't reach the university portal. Please try again.",
        )

    token = await session_store.create_session(ucam_session)
    return LoginResponse(token=token, roll=ucam_session.roll)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(token: BearerToken) -> Response:
    await session_store.destroy(token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me", response_model=MeResponse)
async def me(session: CurrentSession) -> MeResponse:
    return MeResponse(roll=session.roll)
