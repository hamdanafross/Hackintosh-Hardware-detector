# Hackintosh Hardware Detector (Windows) + Kext Suggestions
# Outputs: console summary, report.json, suggestions.md
# Optional: downloads kext release zips from known projects.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ask-Choice($prompt, $choices, $default) {
    $choicesText = ($choices -join "/")
    while ($true) {
        $ans = Read-Host "$prompt [$choicesText] (default: $default)"
        if ([string]::IsNullOrWhiteSpace($ans)) { $ans = $default }
        $ans = $ans.ToUpper()
        if ($choices -contains $ans) { return $ans }
        Write-Host "Invalid choice. Try again."
    }
}

function Get-FirstMatch($items, $pattern) {
    return $items | Where-Object { $_ -match $pattern } | Select-Object -First 1
}

function SafeGetCim($class) {
    try { return Get-CimInstance $class }
    catch { return $null }
}

function Get-PnpFriendly($className) {
    # Example class names: "Display", "Net", "Media"
    try {
        return Get-PnpDevice -PresentOnly |
            Where-Object { $_.Class -eq $className } |
            Select-Object FriendlyName, InstanceId, Manufacturer, Status
    } catch {
        return @()
    }
}

function Detect-Hardware {
    $cpu = SafeGetCim "Win32_Processor" | Select-Object -First 1 Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors
    $cs  = SafeGetCim "Win32_ComputerSystem" | Select-Object -First 1 Manufacturer, Model
    $bios = SafeGetCim "Win32_BIOS" | Select-Object -First 1 SerialNumber, SMBIOSBIOSVersion
    $board = SafeGetCim "Win32_BaseBoard" | Select-Object -First 1 Manufacturer, Product

    $gpus = Get-PnpFriendly "Display"
    $nets = Get-PnpFriendly "Net"
    $audios = Get-PnpFriendly "Media"

    # Storage: list disk drives + controller names (best-effort)
    $disks = SafeGetCim "Win32_DiskDrive" | Select-Object Model, InterfaceType, MediaType, Size
    $storageControllers = @()
    try {
        $storageControllers = Get-PnpDevice -PresentOnly |
            Where-Object { $_.Class -in @("SCSIAdapter","HDC","IDE") } |
            Select-Object FriendlyName, InstanceId, Manufacturer, Status
    } catch { $storageControllers = @() }

    # Rough vendor detection from adapter names
    $netNames = $nets | ForEach-Object { ($_.FriendlyName + " " + $_.Manufacturer) }
    $hasIntelWiFi = [bool](Get-FirstMatch $netNames "Intel.*(Wi-?Fi|Wireless)")
    $hasRealtekEth = [bool](Get-FirstMatch $netNames "Realtek.*(PCIe|GbE|Ethernet|RTL)")
    $hasIntelEth = [bool](Get-FirstMatch $netNames "Intel.*(Ethernet|I\d{4}|I21|I22|I23|LM|V)")
    $hasBroadcomWiFi = [bool](Get-FirstMatch $netNames "Broadcom|BCM")

    $gpuNames = $gpus | ForEach-Object { $_.FriendlyName }
    $hasIntelGPU = [bool](Get-FirstMatch $gpuNames "Intel")
    $hasAmdGPU = [bool](Get-FirstMatch $gpuNames "AMD|Radeon")
    $hasNvidiaGPU = [bool](Get-FirstMatch $gpuNames "NVIDIA|GeForce")

    return [PSCustomObject]@{
        System = [PSCustomObject]@{
            Manufacturer = $cs.Manufacturer
            Model        = $cs.Model
            Serial       = $bios.SerialNumber
            BIOS         = $bios.SMBIOSBIOSVersion
            Board        = "$($board.Manufacturer) $($board.Product)"
        }
        CPU = $cpu
        Devices = [PSCustomObject]@{
            GPUs = $gpus
            NetworkAdapters = $nets
            AudioDevices = $audios
            DiskDrives = $disks
            StorageControllers = $storageControllers
        }
        Flags = [PSCustomObject]@{
            HasIntelGPU = $hasIntelGPU
            HasAmdGPU   = $hasAmdGPU
            HasNvidiaGPU = $hasNvidiaGPU
            HasIntelWiFi = $hasIntelWiFi
            HasBroadcomWiFi = $hasBroadcomWiFi
            HasIntelEthernet = $hasIntelEth
            HasRealtekEthernet = $hasRealtekEth
            HasNVMe = [bool](Get-FirstMatch (($storageControllers | ForEach-Object {$_.FriendlyName}) + ($disks | ForEach-Object {$_.Model})) "NVMe")
        }
    }
}

function Load-KextCatalog($path) {
    if (-not (Test-Path $path)) {
        throw "Missing kext catalog: $path"
    }
    return Get-Content $path -Raw | ConvertFrom-Json
}

function Get-KextSuggestions($hw, $catalog) {
    $suggest = New-Object System.Collections.Generic.List[object]

    # Base always
    foreach ($k in $catalog.base) { $suggest.Add($k) }

    # Graphics suggestions
    if ($hw.Flags.HasIntelGPU -or $hw.Flags.HasAmdGPU) {
        foreach ($k in $catalog.graphics) { $suggest.Add($k) }
    }

    # Audio
    foreach ($k in $catalog.audio) { $suggest.Add($k) }

    # Ethernet
    if ($hw.Flags.HasIntelEthernet) {
        $suggest.Add(($catalog.ethernet | Where-Object id -eq "intelmausi" | Select-Object -First 1))
    }
    if ($hw.Flags.HasRealtekEthernet) {
        $suggest.Add(($catalog.ethernet | Where-Object id -eq "realtekrtl8111" | Select-Object -First 1))
    }

    # Wi-Fi/BT
    if ($hw.Flags.HasIntelWiFi) {
        foreach ($k in $catalog.wifi_bt) { $suggest.Add($k) }
    } elseif ($hw.Flags.HasBroadcomWiFi) {
        # Broadcom guidance is complicated; don’t auto-suggest a single kext here.
        $suggest.Add([PSCustomObject]@{
            id = "broadcom-note"
            name = "Broadcom Wi‑Fi detected (manual research needed)"
            githubLatestZip = ""
            notes = "Broadcom support depends on macOS version and exact chipset. Research required."
        })
    }

    # Storage
    if ($hw.Flags.HasNVMe) {
        foreach ($k in $catalog.storage) { $suggest.Add($k) }
    }

    # Remove nulls / duplicates by id
    $final = $suggest |
        Where-Object { $_ -ne $null } |
        Sort-Object id -Unique

    return $final
}

function Write-SuggestionsMarkdown($path, $hw, $suggestions) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Hackintosh Suggestions (Windows-generated)")
    $lines.Add("")
    $lines.Add("## Detected System")
    $lines.Add("- Manufacturer: $($hw.System.Manufacturer)")
    $lines.Add("- Model: $($hw.System.Model)")
    $lines.Add("- Serial: $($hw.System.Serial)")
    $lines.Add("- BIOS: $($hw.System.BIOS)")
    $lines.Add("- Board: $($hw.System.Board)")
    $lines.Add("")
    $lines.Add("## Suggested Kexts / Notes")
    $lines.Add("> These are suggestions only. Compatibility depends on exact device IDs, macOS version, and OpenCore configuration.")
    $lines.Add("")
    foreach ($k in $suggestions) {
        $lines.Add("### $($k.name)")
        if ($k.githubLatestZip -and $k.githubLatestZip.Trim().Length -gt 0) {
            $lines.Add("- Download: $($k.githubLatestZip)")
        }
        if ($k.notes) {
            $lines.Add("- Notes: $($k.notes)")
        }
        $lines.Add("")
    }
    Set-Content -Path $path -Value ($lines -join "`r`n") -Encoding UTF8
}

function Download-Kexts($suggestions, $downloadDir) {
    New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
    foreach ($k in $suggestions) {
        if (-not $k.githubLatestZip) { continue }
        $url = $k.githubLatestZip.ToString().Trim()
        if ($url.Length -eq 0) { continue }

        $safeName = ($k.id -replace "[^a-zA-Z0-9\-_\.]", "_")
        $out = Join-Path $downloadDir ($safeName + ".zip")

        Write-Host "Downloading $($k.name) -> $out"
        try {
            Invoke-WebRequest -Uri $url -OutFile $out
        } catch {
            Write-Host "  Failed: $url"
        }
    }
}

# ---- Main ----
$mode = Ask-Choice "Output mode?" @("C","F","B") "B"
# C = Console only, F = Files only, B = Both
$doDownload = Ask-Choice "Download kext ZIPs too?" @("Y","N") "N"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$catalogPath = Join-Path $here "kexts.json"

$hw = Detect-Hardware
$catalog = Load-KextCatalog $catalogPath
$suggestions = Get-KextSuggestions -hw $hw -catalog $catalog

# Console output
if ($mode -in @("C","B")) {
    Write-Host ""
    Write-Host "Detected:"
    Write-Host "  System: $($hw.System.Manufacturer) $($hw.System.Model)"
    Write-Host "  Serial: $($hw.System.Serial)"
    Write-Host "  CPU:    $($hw.CPU.Name)"
    Write-Host ""
    Write-Host "Suggested kexts/notes:"
    $suggestions | ForEach-Object {
        Write-Host "  - $($_.name)"
    }
    Write-Host ""
}

# File output
if ($mode -in @("F","B")) {
    $outDir = Join-Path $here "output"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    $reportPath = Join-Path $outDir "report.json"
    $mdPath     = Join-Path $outDir "suggestions.md"

    $hw | ConvertTo-Json -Depth 6 | Set-Content -Path $reportPath -Encoding UTF8
    Write-SuggestionsMarkdown -path $mdPath -hw $hw -suggestions $suggestions

    Write-Host "Wrote:"
    Write-Host "  $reportPath"
    Write-Host "  $mdPath"
}

if ($doDownload -eq "Y") {
    $dlDir = Join-Path $here "downloads"
    Download-Kexts -suggestions $suggestions -downloadDir $dlDir
    Write-Host "Downloads folder: $dlDir"
}

Write-Host "Done."
