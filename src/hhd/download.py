from __future__ import annotations

from pathlib import Path

from hhd.catalog import load_catalog


def suggestions_from_report(report: dict, catalog_path: Path) -> list[dict]:
    cat = load_catalog(catalog_path)
    flags = report.get("flags", {}) or {}

    suggestions: list[dict] = []
    suggestions.extend(cat.get("base", []))

    if flags.get("has_intel_gpu") or flags.get("has_amd_gpu"):
        suggestions.extend(cat.get("graphics", []))

    suggestions.extend(cat.get("audio", []))

    if flags.get("has_intel_ethernet"):
        suggestions.extend([k for k in cat.get("ethernet", []) if k.get("id") == "intelmausi"])
    if flags.get("has_realtek_ethernet"):
        suggestions.extend([k for k in cat.get("ethernet", []) if k.get("id") == "realtekrtl8111"])

    if flags.get("has_intel_wifi"):
        suggestions.extend(cat.get("wifi_bt", []))
    elif flags.get("has_broadcom_wifi"):
        suggestions.append(
            {
                "id": "broadcom-note",
                "name": "Broadcom Wi‑Fi detected (manual research needed)",
                "githubLatestZip": "",
                "notes": "Broadcom support depends on macOS version and exact chipset. Research required.",
            }
        )

    if flags.get("has_nvme"):
        suggestions.extend(cat.get("storage", []))

    # de-dupe by id
    by_id: dict[str, dict] = {}
    for s in suggestions:
        sid = s.get("id")
        if sid and sid not in by_id:
            by_id[sid] = s
    return list(by_id.values())


def write_suggestions_markdown(path: Path, report: dict, suggestions: list[dict]) -> None:
    sysinfo = report.get("system", {}) or {}
    lines: list[str] = []
    lines.append("# Hackintosh Suggestions")
    lines.append("")
    lines.append("## Detected System")
    for k in ["os", "manufacturer", "model", "serial", "bios"]:
        if k in sysinfo and sysinfo[k]:
            lines.append(f"- {k.title()}: {sysinfo[k]}")
    lines.append("")
    lines.append("## Suggested Kexts / Notes")
    lines.append("> These are suggestions only. Compatibility depends on exact device IDs, macOS version, and OpenCore configuration.")
    lines.append("")
    for k in suggestions:
        lines.append(f"### {k.get('name','(unknown)')}")
        url = (k.get("githubLatestZip") or "").strip()
        if url:
            lines.append(f"- Download: {url}")
        notes = (k.get("notes") or "").strip()
        if notes:
            lines.append(f"- Notes: {notes}")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")
