param(
    [string]$SiteName = "ScoreCore",
    [string]$AppPoolName = "ScoreCorePool",
    [string]$RootPath = "C:\inetpub\scorecore",
    [int]$Port = 8088,
    [string]$HostHeader = "",
    [int]$BackendPort = 8181
)

$ErrorActionPreference = "Stop"

Import-Module WebAdministration

$paths = @(
    $RootPath,
    (Join-Path $RootPath "backend"),
    (Join-Path $RootPath "frontend"),
    (Join-Path $RootPath "media"),
    (Join-Path $RootPath "static"),
    (Join-Path $RootPath "logs"),
    (Join-Path $RootPath "deploy"),
    (Join-Path $RootPath "sql")
)

foreach ($path in $paths) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

if (-not (Test-Path "IIS:\AppPools\$AppPoolName")) {
    New-WebAppPool -Name $AppPoolName | Out-Null
}

Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name managedRuntimeVersion -Value ""
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name processModel.identityType -Value "ApplicationPoolIdentity"
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name startMode -Value "AlwaysRunning"
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name recycling.periodicRestart.time -Value "00:00:00"

$bindingInformation = "*:${Port}:$HostHeader"

if (-not (Test-Path "IIS:\Sites\$SiteName")) {
    New-Website -Name $SiteName `
        -PhysicalPath (Join-Path $RootPath "frontend") `
        -Port $Port `
        -HostHeader $HostHeader `
        -ApplicationPool $AppPoolName | Out-Null
} else {
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value (Join-Path $RootPath "frontend")
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name applicationPool -Value $AppPoolName

    $existingBinding = Get-WebBinding -Name $SiteName -Protocol "http" |
        Where-Object { $_.bindingInformation -eq $bindingInformation }
    if (-not $existingBinding) {
        New-WebBinding -Name $SiteName -Protocol "http" -Port $Port -HostHeader $HostHeader | Out-Null
    }
}

$aclTargets = @("media", "static", "logs")
foreach ($name in $aclTargets) {
    $path = Join-Path $RootPath $name
    $identity = "IIS AppPool\$AppPoolName"
    & icacls $path /grant "${identity}:(OI)(CI)M" /T | Out-Null
}

Write-Host "ScoreCore IIS site is ready."
Write-Host "Site:      $SiteName"
Write-Host "AppPool:   $AppPoolName"
Write-Host "Frontend:  $(Join-Path $RootPath 'frontend')"
Write-Host "Backend:   http://127.0.0.1:$BackendPort"
$displayHost = "localhost"
if ($HostHeader -ne "") {
    $displayHost = $HostHeader
}
Write-Host "Binding:   http://${displayHost}:$Port"
