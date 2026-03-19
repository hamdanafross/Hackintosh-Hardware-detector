from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from hhd.detect import detect_hardware
from hhd.suggest import suggestions_from_report, write_suggestions_markdown


def main() -> None:
    p = argparse.ArgumentParser(prog="hhd", description="Hackintosh Hardware Detector (cross-platform)")
    p.add_argument("--out", default="output", help="Output directory (default: output)")
    p.add_argument("--catalog", default="kext.json", help="Kext catalog json file (default: kext.json)")
    p.add_argument("--download-kexts", action="store_true", help="(Opt-in) Download kext zip URLs to downloads/")
    args = p.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    report = detect_hardware()
    report_path = out_dir / "report.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")

    suggestions = suggestions_from_report(report, Path(args.catalog))
    md_path = out_dir / "suggestions.md"
    write_suggestions_markdown(md_path, report, suggestions)

    print(f"Wrote:\n  {report_path}\n  {md_path}")

    if args.download_kexts:
        from hhd.download import download_kext_zips

        dl_dir = Path("downloads")
        dl_dir.mkdir(parents=True, exist_ok=True)
        download_kext_zips(suggestions, dl_dir)
        print(f"Downloads folder: {dl_dir}")

    print("Done.")
