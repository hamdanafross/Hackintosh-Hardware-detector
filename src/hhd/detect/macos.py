from __future__ import annotations

import subprocess


def _run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT)


def detect_macos() -> dict:
    # Best-effort using system_profiler (available on macOS)
    hw = _run(["system_profiler", "SPHardwareDataType"])
    net = _run(["system_profiler", "SPNetworkDataType"])
    gfx = _run(["system_profiler", "SPDisplaysDataType"])

    text = (hw + "\n" + net + "\n" + gfx).lower()

    flags = {
        "has_intel_gpu": "intel" in text and ("graphics" in text or "display" in text),
        "has_amd_gpu": "amd" in text or "radeon" in text,
        "has_nvidia_gpu": "nvidia" in text or "geforce" in text,
        "has_intel_wifi": "intel" in text and ("wi-fi" in text or "wifi" in text),
        "has_broadcom_wifi": "broadcom" in text or "bcm" in text,
        "has_intel_ethernet": "intel" in text and "ethernet" in text,
        "has_realtek_ethernet": "realtek" in text and "ethernet" in text,
        "has_nvme": "nvme" in text,
    }

    return {
        "system": {"os": "macos"},
        "raw": {"system_profiler": {"hardware": hw, "network": net, "displays": gfx}},
        "devices": {},
        "flags": flags,
    }
