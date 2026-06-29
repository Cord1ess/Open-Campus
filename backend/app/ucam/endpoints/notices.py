"""GetNotice — university notices.

Verified PageMethod: POST /Security/StudentHome.aspx/GetNotice
Body (from the page's own JS): {"program": "<programId> ", "roll": "<id>"}
  → {"d": "<json-string-array>"} where each item is
    {Type, WithdrawDate, Program, PostedDate, PostedBy, NoticeTitle,
     NoticeDescription, FilePath, CreatedDate, NoticeId}

The earlier 500 was because the probe omitted `program`. The page reads
`program` from the hidden field hdnProgramId and sends it WITH a trailing space
("<id> "); we reproduce that exactly. `d` is itself a JSON string, so we parse it.
"""
from __future__ import annotations

import json
import logging

from app.schemas.student import Notice
from app.ucam.client import UcamSession, call_page_method

METHOD = "GetNotice"
_DEFAULT_PROGRAM = "1"
log = logging.getLogger("open_campus.notices")


async def fetch_notices(
    session: UcamSession, program: str = _DEFAULT_PROGRAM
) -> list[Notice]:
    # The page sends program with a trailing space (see StudentHome JS); match it.
    raw = await call_page_method(
        session, METHOD, {"program": f"{program} ", "roll": session.roll}
    )
    return parse_notices(raw)


def parse_notices(raw: object) -> list[Notice]:
    """`d` is a JSON-encoded string array (or already a list / empty). Tolerant."""
    items: object = raw
    if isinstance(raw, str):
        if not raw.strip():
            return []
        try:
            items = json.loads(raw)
        except json.JSONDecodeError:
            log.warning("notices: d was a non-JSON string")
            return []
    if not isinstance(items, list):
        return []
    out: list[Notice] = []
    for it in items:
        if isinstance(it, dict):
            try:
                out.append(Notice.model_validate(it))
            except Exception:  # skip a malformed item rather than fail all
                continue
    return out
