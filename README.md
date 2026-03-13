# Hackintosh Hardware Detector (Windows)

PowerShell script that detects PC hardware on Windows and suggests common OpenCore kexts (and can optionally download release ZIPs).

## Run
Download the repo and run in PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\hackintosh-detector.ps1
```

## Output
- Console summary
- `output/report.json`
- `output/suggestions.md`
- Optional: `downloads/*.zip`

## Notes
- Suggestions only; Hackintosh compatibility depends on exact device IDs, macOS version, BIOS settings, and OpenCore configuration.
- This tool does not install macOS and does not include Apple software.
