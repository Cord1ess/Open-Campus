"""Section-catalog loading + shape tests (offline, no live calls).

Verifies the committed catalog file parses into the schema, and that the
loader's mtime-based memoization reloads a changed file. Also guards the
privacy contract: the served catalog must NOT contain live-occupancy or
per-student fields.
"""
from __future__ import annotations

import json

import pytest

from app.schemas.catalog import SectionCatalog


def test_committed_catalog_parses_and_is_clean():
    from app.api import catalog

    if not catalog._CATALOG_PATH.exists():
        pytest.skip("no committed catalog file in this tree")

    raw = catalog._CATALOG_PATH.read_text(encoding="utf-8")
    model = SectionCatalog.model_validate(json.loads(raw))
    assert model.courses, "catalog should have courses"

    # Every section is classified and structural-only.
    for course in model.courses:
        for sec in course.sections:
            assert sec.kind in {"theory", "lab", "unscheduled", "other"}

    # Privacy contract: none of these live/personal fields may ship.
    for banned in (
        "seats_taken", "seat_info", "is_enrolled", "isMapped",
        "section_id", "ucam_ref", "faculty_email",
    ):
        assert banned not in raw, f"{banned} leaked into the committed catalog"


def test_loader_memoizes_and_reloads_on_mtime(tmp_path, monkeypatch):
    from app.api import catalog

    f = tmp_path / "section_catalog.json"
    f.write_text(json.dumps({
        "trimester": "t1",
        "courses": [{"formal_code": "CSE 1111", "sections": [
            {"section": "A", "kind": "theory",
             "schedule": [{"day": "Saturday", "start": "08:30", "end": "09:50"}]}
        ]}],
    }), encoding="utf-8")

    monkeypatch.setattr(catalog, "_CATALOG_PATH", f)
    monkeypatch.setattr(catalog, "_cache", None)
    monkeypatch.setattr(catalog, "_cache_mtime", None)

    first = catalog._load_catalog()
    assert first.trimester == "t1"
    # Same object returned while the file is unchanged (memoized).
    assert catalog._load_catalog() is first

    # Rewrite with a newer mtime -> loader must pick up the new content.
    import os
    st = f.stat()
    f.write_text(json.dumps({"trimester": "t2", "courses": []}), encoding="utf-8")
    os.utime(f, (st.st_atime, st.st_mtime + 10))
    second = catalog._load_catalog()
    assert second.trimester == "t2"


def test_missing_file_yields_empty_catalog(tmp_path, monkeypatch):
    from app.api import catalog

    monkeypatch.setattr(catalog, "_CATALOG_PATH", tmp_path / "does_not_exist.json")
    monkeypatch.setattr(catalog, "_cache", None)
    monkeypatch.setattr(catalog, "_cache_mtime", None)

    result = catalog._load_catalog()
    assert result.courses == []
