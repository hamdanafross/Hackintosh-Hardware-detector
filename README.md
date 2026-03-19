# Hackintosh Hardware Detector

Cross-platform hardware detection (Windows/macOS/Linux) with OpenCore kext suggestions.

## Download (Recommended)

1. Go to the GitHub **Releases** page
2. Download the asset for your OS + CPU:
   - Windows: `Hackintosh-Hardware-detector-Windows-x64.zip` / `...-arm64.zip`
   - macOS: `Hackintosh-Hardware-detector-macOS-x64.tar.gz` / `...-arm64.tar.gz`
   - Linux: `Hackintosh-Hardware-detector-Linux-x64.tar.gz` / `...-arm64.tar.gz`
3. Extract the archive
4. Run:
   - Windows: `hhd.exe`
   - macOS/Linux: `./hhd`

Outputs:
- `output/report.json`
- `output/suggestions.md`

## Run from source (Advanced)

```bash
python -m venv .venv
# Windows: .\.venv\Scripts\activate
# macOS/Linux: source .venv/bin/activate
pip install -e .
hhd
```

## Optional downloads

By default the tool does not download anything.
To download kext ZIPs listed in the catalog:

```bash
hhd --download-kexts
```

## Notes

- Suggestions only; Hackintosh compatibility depends on exact device IDs, macOS version, BIOS settings, and OpenCore configuration.
- This tool does not install macOS and does not include Apple software.
