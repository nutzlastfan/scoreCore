param(
    [string]$ProjectRoot = "C:\scorecore\app",
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 8181
)

$ErrorActionPreference = "Stop"

Set-Location $ProjectRoot

$python = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
    throw "Python venv not found at $python"
}

& $python -m daphne -b $HostAddress -p $Port server.asgi:application
