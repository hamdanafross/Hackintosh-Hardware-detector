from __future__ import annotations

import platform

from hhd.detect.linux import detect_linux
from hhd.detect.macos import detect_macos
from hhd.detect.windows import detect_windows


def detect_hardware() -> dict:
    system = platform.system().lower()
    if system == "windows":
        return detect_windows()
    if system == "darwin":
        return detect_macos()
    if system == "linux":
        return detect_linux()
    return {
        "system": {"os": system, "note": "Unsupported OS"},
        "devices": {},
        "flags": {},
    }
