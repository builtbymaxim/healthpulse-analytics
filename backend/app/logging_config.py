"""Structured JSON logging configuration."""

import json
import logging
from datetime import datetime, timezone


class JSONFormatter(logging.Formatter):
    """Emits each log record as a single JSON line, including the current request ID."""

    def format(self, record: logging.LogRecord) -> str:
        # Import here to avoid circular imports at module load time
        from app.middleware.request_id import request_id_var

        log_obj: dict = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "request_id": request_id_var.get(""),
        }

        if record.exc_info and record.exc_info[0] is not None:
            log_obj["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_obj)


def setup_logging(debug: bool = False) -> None:
    """Configure root logger with JSON output. Call once at startup."""
    handler = logging.StreamHandler()
    handler.setFormatter(JSONFormatter())

    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(logging.DEBUG if debug else logging.INFO)

    # Quiet noisy third-party libraries
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
