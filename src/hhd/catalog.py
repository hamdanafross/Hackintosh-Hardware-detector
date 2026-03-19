from __future__ import annotations

import json
from pathlib import Path


def load_catalog(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Missing kext catalog: {path}")
    return json.loads(path.read_text(encoding="utf-8"))
