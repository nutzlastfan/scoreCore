param(
    [string]$ServiceName = "ScoreCoreBackend",
    [string]$ProjectRoot = "C:\inetpub\scorecore\backend",
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 8181,
    [string]$LogRoot = "C:\inetpub\scorecore\logs",
    [switch]$Reinstall
)

$ErrorActionPreference = "Stop"

$nssmCommand = Get-Command nssm.exe -ErrorAction SilentlyContinue
if (-not $nssmCommand) {
    throw "nssm.exe was not found. Install NSSM first, for example: choco install nssm -y"
}

if (-not (Test-Path $ProjectRoot)) {
    throw "ProjectRoot not found: $ProjectRoot"
}

$startScript = Join-Path $ProjectRoot "deploy\windows\start-backend.ps1"
if (-not (Test-Path $startScript)) {
    throw "Backend start script not found: $startScript"
}

if (-not (Test-Path $LogRoot)) {
    New-Item -ItemType Directory -Path $LogRoot | Out-Null
}

$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService -and -not $Reinstall) {
    throw "Service '$ServiceName' already exists. Use -Reinstall to replace it."
}

$nssm = $nssmCommand.Source
$powershell = Join-Path $PSHOME "powershell.exe"

if ($existingService) {
    & $nssm stop $ServiceName | Out-Host
    & $nssm remove $ServiceName confirm | Out-Host
}

& $nssm install $ServiceName $powershell | Out-Host
& $nssm set $ServiceName AppDirectory $ProjectRoot | Out-Host
& $nssm set $ServiceName AppParameters "-NoProfile -ExecutionPolicy Bypass -File `"$startScript`" -ProjectRoot `"$ProjectRoot`" -HostAddress $HostAddress -Port $Port" | Out-Host
& $nssm set $ServiceName DisplayName "ScoreCore Backend" | Out-Host
& $nssm set $ServiceName Description "Daphne ASGI backend for ScoreCore behind IIS ARR." | Out-Host
& $nssm set $ServiceName Start SERVICE_AUTO_START | Out-Host
& $nssm set $ServiceName AppStdout (Join-Path $LogRoot "backend.out.log") | Out-Host
& $nssm set $ServiceName AppStderr (Join-Path $LogRoot "backend.err.log") | Out-Host
& $nssm set $ServiceName AppRotateFiles 1 | Out-Host
& $nssm set $ServiceName AppRotateOnline 1 | Out-Host
& $nssm set $ServiceName AppRotateBytes 10485760 | Out-Host

Start-Service $ServiceName
Get-Service $ServiceName
