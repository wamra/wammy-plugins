# Shared helpers for locating/installing PowerShell Editor Services.
# Dot-sourced by start-pses.ps1 (LSP launch) and ensure-pses.ps1 (SessionStart hook).

$script:PsesReleaseUrl = if ($env:CLAUDE_PSES_URL) { $env:CLAUDE_PSES_URL } else {
    'https://github.com/PowerShell/PowerShellEditorServices/releases/latest/download/PowerShellEditorServices.zip'
}

function Get-PsesCacheDir {
    if ($env:CLAUDE_PSES_PATH) { return $env:CLAUDE_PSES_PATH }
    if ($IsWindows)    { $base = $env:LOCALAPPDATA }
    elseif ($IsMacOS)  { $base = Join-Path $HOME 'Library/Caches' }
    else               { $base = if ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else { Join-Path $HOME '.cache' } }
    return Join-Path $base 'claude-powershell-lsp'
}

function Get-PsesStartScript {
    $candidate = Join-Path (Get-PsesCacheDir) 'pses/PowerShellEditorServices/Start-EditorServices.ps1'
    if (Test-Path $candidate) { return $candidate }
    return $null
}

function Get-PsesZip {
    param([string]$Destination)
    # 1. Explicit local zip (air-gapped / corporate mirror installs)
    if ($env:CLAUDE_PSES_ZIP -and (Test-Path $env:CLAUDE_PSES_ZIP)) {
        Copy-Item $env:CLAUDE_PSES_ZIP $Destination -Force
        return
    }
    # 2. curl first (ships with macOS, Windows 10+, and most Linux distros;
    #    endpoint-security tools that block .NET networking usually allow it)
    $curl = Get-Command curl -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($curl) {
        & $curl.Source -sfL --max-time 300 -o $Destination $script:PsesReleaseUrl
        if ($LASTEXITCODE -eq 0 -and (Test-Path $Destination)) { return }
    }
    # 3. Invoke-WebRequest fallback, with a hard timeout so a blocked network
    #    fails fast instead of hanging the LSP startup
    try {
        $oldProgress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $script:PsesReleaseUrl -OutFile $Destination -MaximumRedirection 5 -TimeoutSec 120
        return
    }
    catch { }
    finally { $ProgressPreference = $oldProgress }
    throw "Could not download PowerShell Editor Services from $script:PsesReleaseUrl (network blocked?). Set CLAUDE_PSES_ZIP to a local copy of PowerShellEditorServices.zip and retry."
}

function Install-Pses {
    # Quiet by design: when called from the LSP launch path, stdout belongs to the
    # LSP protocol stream and must not be polluted.
    $cacheDir = Get-PsesCacheDir
    $zipPath = Join-Path ([IO.Path]::GetTempPath()) "pses-download-$PID.zip"
    try {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        Get-PsesZip -Destination $zipPath
        $target = Join-Path $cacheDir 'pses'
        if (Test-Path $target) { Remove-Item -Recurse -Force $target }
        Expand-Archive -Path $zipPath -DestinationPath $target -Force
    }
    finally {
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    }
    $startScript = Get-PsesStartScript
    if (-not $startScript) { throw "PowerShell Editor Services install failed: Start-EditorServices.ps1 not found under $cacheDir" }
    return $startScript
}
