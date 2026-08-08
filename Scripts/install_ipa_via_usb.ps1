param(
    [Parameter(Mandatory = $true)]
    [string]$IpaPath,

    [string]$PythonPath = "C:\Users\11332\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe",
    [string]$PyMobileDevicePath = "C:\Users\11332\Documents\Codex\2026-08-07\new-chat-2\work\pymobiledevice3",
    [string]$SshKeyPath = "C:\Users\11332\Documents\Codex\2026-08-07\new-chat-2\work\iphone_ssh\shadowlite_ed25519",
    [int]$LocalSshPort = 2222
)

$ErrorActionPreference = "Stop"

if (!(Test-Path -LiteralPath $IpaPath)) {
    throw "IPA not found: $IpaPath"
}

if (!(Test-Path -LiteralPath $PythonPath)) {
    throw "Python runtime not found: $PythonPath"
}

if (!(Test-Path -LiteralPath $PyMobileDevicePath)) {
    throw "pymobiledevice3 path not found: $PyMobileDevicePath"
}

if (!(Test-Path -LiteralPath $SshKeyPath)) {
    throw "SSH key not found: $SshKeyPath"
}

$forwardScript = Join-Path $env:TEMP "shadowlite_usbmux_forward_$LocalSshPort.py"
$forwardBody = @"
import os, sys, runpy
base = os.path.abspath(r"$PyMobileDevicePath")
sys.path[:0] = [base, os.path.join(base, "win32"), os.path.join(base, "win32", "lib"), os.path.join(base, "Pythonwin")]
os.add_dll_directory(os.path.join(base, "pywin32_system32"))
sys.argv = ["pymobiledevice3", "usbmux", "forward", "$LocalSshPort", "22"]
runpy.run_module("pymobiledevice3", run_name="__main__")
"@

Set-Content -LiteralPath $forwardScript -Value $forwardBody -Encoding ASCII

$portOpen = Test-NetConnection 127.0.0.1 -Port $LocalSshPort -InformationLevel Quiet
if (!$portOpen) {
    $process = Start-Process -FilePath $PythonPath -ArgumentList "`"$forwardScript`"" -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 3
}

$portOpen = Test-NetConnection 127.0.0.1 -Port $LocalSshPort -InformationLevel Quiet
if (!$portOpen) {
    throw "USB SSH forwarding did not open on 127.0.0.1:$LocalSshPort"
}

$ipaName = Split-Path -Leaf $IpaPath
$remotePath = "/var/mobile/Documents/$ipaName"

scp -i $SshKeyPath -P $LocalSshPort -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL $IpaPath "mobile@127.0.0.1:$remotePath"
ssh -i $SshKeyPath -p $LocalSshPort -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL mobile@127.0.0.1 "ls -lh '$remotePath'; uiopen --path '$remotePath'"

Write-Host "IPA copied to iPhone: $remotePath"
Write-Host "If TrollStore does not open automatically, open TrollStore manually and import the IPA from Files/Documents."
