param(
    [string]$Server = "vetweb01",
    [string]$ShareRoot = "\\vetweb01\c$\inetpub\scorecore",
    [string]$NodeRoot = "D:\OHIF-FUBerlin-fuberlinV3\tools\node20\node-v20.20.2-win-x64",
    [string]$BuildWorkDir = "D:\scorecore-frontend-build",
    [string]$RepoRoot = "",
    [string]$FrontendUrl = "https://vetweb01.vetmed.fu-berlin.de/scoring",
    [string]$BackendUrl = "https://vetweb01.vetmed.fu-berlin.de",
    [string]$WebSocketUrl = "wss://vetweb01.vetmed.fu-berlin.de",
    [string]$PublicUrl = "/scoring/",
    [switch]$SkipFrontendBuild,
    [switch]$StaticOnlyWebConfig
)

$ErrorActionPreference = "Stop"

function Normalize-PublicUrl {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "/"
    }

    $normalized = $Value.Trim()
    if (-not $normalized.StartsWith("/")) {
        $normalized = "/$normalized"
    }
    if (-not $normalized.EndsWith("/")) {
        $normalized = "$normalized/"
    }

    return $normalized
}

function Write-FrontendWebConfig {
    param(
        [string]$TemplatePath,
        [string]$TargetPath,
        [string]$PublicUrl
    )

    $publicPath = $PublicUrl.Trim("/")
    $publicPathRegex = [regex]::Escape($publicPath)
    $content = Get-Content -Path $TemplatePath -Raw
    $content = $content.Replace("__PUBLIC_URL__", $PublicUrl)
    $content = $content.Replace("__PUBLIC_PATH_REGEX__", $publicPathRegex)
    Set-Content -Path $TargetPath -Value $content -Encoding UTF8
}

$PublicUrl = Normalize-PublicUrl $PublicUrl

if ($RepoRoot -eq "") {
    if ($PSScriptRoot -ne "") {
        $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    } else {
        $RepoRoot = Resolve-Path "."
    }
} else {
    $RepoRoot = Resolve-Path $RepoRoot
}

$repoRoot = $RepoRoot
$frontendSource = Join-Path $repoRoot "frontend"
$frontendTarget = Join-Path $ShareRoot "frontend"
$backendTarget = Join-Path $ShareRoot "backend"
$deployTarget = Join-Path $ShareRoot "deploy"
$sqlTarget = Join-Path $ShareRoot "sql"

foreach ($path in @($ShareRoot, $frontendTarget, $backendTarget, $deployTarget, $sqlTarget)) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

if (-not $SkipFrontendBuild) {
    if (Test-Path $BuildWorkDir) {
        Remove-Item -LiteralPath $BuildWorkDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $BuildWorkDir | Out-Null

    robocopy $frontendSource $BuildWorkDir /E /XD node_modules dist /XF package-lock.json | Out-Host
    if ($LASTEXITCODE -ge 8) {
        throw "Frontend copy to build directory failed with robocopy exit code $LASTEXITCODE"
    }

    @"
SKIP_PREFLIGHT_CHECK=false
PUBLIC_URL=$PublicUrl
REACT_APP_FRONTEND_URL=$FrontendUrl
REACT_APP_BACKEND_URL=$BackendUrl
REACT_APP_WS_URL=$WebSocketUrl
REACT_APP_BASE_WS=$WebSocketUrl
REACT_APP_DOCKER_ENABLED=0
"@ | Set-Content -Path (Join-Path $BuildWorkDir ".env.production") -Encoding ASCII

    $env:PATH = "$NodeRoot;$env:PATH"
    Push-Location $BuildWorkDir
    try {
        & (Join-Path $NodeRoot "npm.cmd") install
        & (Join-Path $NodeRoot "npm.cmd") run build
    } finally {
        Pop-Location
    }

    robocopy (Join-Path $BuildWorkDir "dist") $frontendTarget /MIR | Out-Host
    if ($LASTEXITCODE -ge 8) {
        throw "Frontend deployment failed with robocopy exit code $LASTEXITCODE"
    }

    $webConfigName = "frontend.web.config"
    if ($StaticOnlyWebConfig) {
        $webConfigName = "frontend.static.web.config"
    }
    $webConfigTemplate = Join-Path $repoRoot "deploy\windows\$webConfigName"
    $webConfigTarget = Join-Path $frontendTarget "web.config"
    if ($StaticOnlyWebConfig) {
        Copy-Item $webConfigTemplate $webConfigTarget -Force
    } else {
        Write-FrontendWebConfig -TemplatePath $webConfigTemplate -TargetPath $webConfigTarget -PublicUrl $PublicUrl
    }
}

robocopy $repoRoot $backendTarget /MIR `
    /XD .git frontend node_modules media static .venv venv `
    /XF django.env package-lock.json | Out-Host
if ($LASTEXITCODE -ge 8) {
    throw "Backend deployment failed with robocopy exit code $LASTEXITCODE"
}

robocopy (Join-Path $repoRoot "deploy") $deployTarget /E | Out-Host
if ($LASTEXITCODE -ge 8) {
    throw "Deploy artifact copy failed with robocopy exit code $LASTEXITCODE"
}

robocopy (Join-Path $repoRoot "deploy\sqlserver") $sqlTarget /E | Out-Host
if ($LASTEXITCODE -ge 8) {
    throw "SQL script copy failed with robocopy exit code $LASTEXITCODE"
}

Write-Host "ScoreCore files deployed to $ShareRoot on $Server."
