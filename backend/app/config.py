"""Application configuration, loaded from environment / .env.

Every secret is env-driven (prefix OC_). Nothing sensitive is hard-coded; the
defaults here are dev-only and MUST be overridden in the deployed instance.
See .env.example for the full list.
"""
from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict

_DEV_SECRET_PLACEHOLDER = "CHANGE-ME-dev-only-secret"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="OC_", extra="ignore")

    # --- UCAM target (verified, see docs/RECON.md) ---
    ucam_base_url: str = "https://ucam.uiu.ac.bd"
    ucam_login_path: str = "/Security/Login.aspx"
    ucam_home_path: str = "/Security/StudentHome.aspx"
    # A real browser UA. UCAM is a normal site; we present as a standard browser.
    user_agent: str = (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
    )
    # Read timeout (seconds) when talking to UCAM. UCAM's login can be slow.
    ucam_timeout_seconds: float = 45.0

    # --- Our auth tokens (NOT UCAM credentials) ---
    # Secret used to sign the Open Campus JWT we hand to the app. The live UCAM
    # session lives in-memory server-side, keyed by this token's subject, only
    # while the user is active. The UCAM password is NEVER stored anywhere.
    # The server is otherwise stateless — no database.
    # A dev placeholder default keeps local dev/tests frictionless, but
    # require_production_safety() (called at startup) REFUSES to run with it when
    # debug is off. Override OC_SESSION_SECRET in any real deployment.
    session_secret: str = _DEV_SECRET_PLACEHOLDER
    session_ttl_minutes: int = 60  # how long our token is valid before re-login

    # --- Rate limiting (be a good citizen toward UCAM) ---
    # Minimum seconds between UCAM-bound requests for a single user session.
    per_user_min_interval_seconds: float = 1.0

    # --- App ---
    # CORS: empty by default. A native Flutter app doesn't need CORS; only set
    # origins for a browser/web build, and never combine "*" with credentials.
    cors_origins: list[str] = []
    debug: bool = False  # safe default; enable only for local dev

    def require_production_safety(self) -> None:
        """Fail-closed checks for a real deployment. Called at startup; raises if
        the config is unsafe while debug is off."""
        if self.debug:
            return  # local dev — allow placeholder secret, etc.
        problems = []
        if self.session_secret == _DEV_SECRET_PLACEHOLDER:
            problems.append("OC_SESSION_SECRET is still the dev placeholder.")
        if len(self.session_secret) < 32:
            problems.append("OC_SESSION_SECRET is too short (use >= 32 chars).")
        if "*" in self.cors_origins:
            problems.append('OC_CORS_ORIGINS must not be "*" in production.')
        if problems:
            raise RuntimeError(
                "Unsafe production config (set OC_DEBUG=true for local dev): "
                + " ".join(problems)
            )


settings = Settings()
