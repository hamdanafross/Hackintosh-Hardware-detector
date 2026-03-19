from __future__ import annotations

import json
import subprocess


def _ps_json(cmd: str) -> object:
    # Run PowerShell and parse JSON output
    full = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        cmd,
    ]
    out = subprocess.check_output(full, text=True, stderr=subprocess.STDOUT)
    return json.loads(out)


def detect_windows() -> dict:
    cpu = _ps_json("Get-CimInstance Win32_Processor | Select-Object -First 1 Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors | ConvertTo-Json")
    cs = _ps_json("Get-CimInstance Win32_ComputerSystem | Select-Object -First 1 Manufacturer,Model | ConvertTo-Json")
    bios = _ps_json("Get-CimInstance Win32_BIOS | Select-Object -First 1 SerialNumber,SMBIOSBIOSVersion | ConvertTo-Json")

    # PnP devices (best-effort)
    gpus = _ps_json("Get-PnpDevice -PresentOnly | Where-Object {$_.Class -eq 'Display'} | Select-Object FriendlyName,InstanceId,Manufacturer,Status | ConvertTo-Json")
    nets = _ps_json("Get-PnpDevice -PresentOnly | Where-Object {$_.Class -eq 'Net'} | Select-Object FriendlyName,InstanceId,Manufacturer,Status | ConvertTo-Json")
    medias = _ps_json("Get-PnpDevice -PresentOnly | Where-Object {$_.Class -eq 'Media'} | Select-Object FriendlyName,InstanceId,Manufacturer,Status | ConvertTo-Json")

    # Ensure lists (ConvertTo-Json can return object if single element)
    def _as_list(x):
        return x if isinstance(x, list) else ([] if x is None else [x])

    gpus = _as_list(gpus)
    nets = _as_list(nets)
    medias = _as_list(medias)

    net_names = " ".join([(d.get("FriendlyName","") + " " + d.get("Manufacturer","")) for d in nets]).lower()
    gpu_names = " ".join([d.get("FriendlyName","") for d in gpus]).lower()

    flags = {
        "has_intel_gpu": "intel" in gpu_names,
        "has_amd_gpu": ("amd" in gpu_names) or ("radeon" in gpu_names),
        "has_nvidia_gpu": ("nvidia" in gpu_names) or ("geforce" in gpu_names),
        "has_intel_wifi": ("intel" in net_names) and ("wi-fi" in net_names or "wifi" in net_names or "wireless" in net_names),
        "has_broadcom_wifi": ("broadcom" in net_names) or ("bcm" in net_names),
        "has_intel_ethernet": ("intel" in net_names) and ("ethernet" in net_names),
        "has_realtek_ethernet": ("realtek" in net_names) and ("ethernet" in net_names or "gbe" in net_names or "rtl" in net_names),
        "has_nvme": False,  # TODO: improve (can be added later)
    }

    return {
        "system": {
            "os": "windows",
            "manufacturer": cs.get("Manufacturer"),
            "model": cs.get("Model"),
            "serial": bios.get("SerialNumber"),
            "bios": bios.get("SMBIOSBIOSVersion"),
        },
        "cpu": cpu,
        "devices": {
            "gpus": gpus,
            "network_adapters": nets,
            "audio_devices": medias,
        },
        "flags": flags,
    }
