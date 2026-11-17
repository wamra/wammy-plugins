# Shared helpers for locating/installing PowerShell Editor Services.
# Dot-sourced by start-pses.ps1 (LSP launch) and ensure-pses.ps1 (SessionStart hook).
#
# Cache layout: <cache>/versions/<version>/PowerShellEditorServices/... — one
# directory per PSES release, so an update never overwrites files a running
# language server still has loaded. <cache>/pses (the pre-0.3.0 layout) is still
# recognised.

$script:PsesRepoUrl = 'https://github.com/PowerShell/PowerShellEditorServices'
$script:PsesUpdateCheckHours = 24

function Get-PsesPinnedVersion {
    # CLAUDE_PSES_VERSION pins an exact release ("4.7.0" or "v4.7.0").
    # Unset or "latest" means: track the newest release.
    $raw = "$env:CLAUDE_PSES_VERSION".Trim()
    if (-not $raw -or $raw -eq 'latest') { return $null }
    $parsed = $null
    if (-not [version]::TryParse($raw.TrimStart('v', 'V'), [ref]$parsed)) {
        throw "CLAUDE_PSES_VERSION '$raw' is not a release version (expected e.g. 4.7.0)."
    }
    return [version]::new($parsed.Major, $parsed.Minor, [Math]::Max($parsed.Build, 0))
}

function Get-PsesReleaseUrl {
    if ($env:CLAUDE_PSES_URL) { return $env:CLAUDE_PSES_URL }
    $pin = Get-PsesPinnedVersion
    if ($pin) { return "$script:PsesRepoUrl/releases/download/v$pin/PowerShellEditorServices.zip" }
    return "$script:PsesRepoUrl/releases/latest/download/PowerShellEditorServices.zip"
}

function Get-PsesCacheDir {
    if ($env:CLAUDE_PSES_PATH) { return $env:CLAUDE_PSES_PATH }
    if ($IsWindows)    { $base = $env:LOCALAPPDATA }
    elseif ($IsMacOS)  { $base = Join-Path $HOME 'Library/Caches' }
    else               { $base = if ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else { Join-Path $HOME '.cache' } }
    return Join-Path $base 'claude-powershell-lsp'
}

function Get-PsesBundleVersion {
    param([string]$BundleRoot)
    $manifest = Join-Path $BundleRoot 'PowerShellEditorServices/PowerShellEditorServices.psd1'
    if (-not (Test-Path $manifest)) { return $null }
    # Matched as text: the manifest computes RootModule with an `if`, which
    # Import-PowerShellDataFile rejects as a dynamic expression.
    $line = Select-String -Path $manifest -Pattern "^\s*ModuleVersion\s*=\s*'([\d.]+)'" | Select-Object -First 1
    $parsed = $null
    if ($line -and [version]::TryParse($line.Matches[0].Groups[1].Value, [ref]$parsed)) { return $parsed }
    return $null
}

function Get-PsesInstalled {
    $cacheDir = Get-PsesCacheDir
    $roots = @(Get-ChildItem (Join-Path $cacheDir 'versions') -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName)
    $roots += Join-Path $cacheDir 'pses'
    foreach ($root in $roots) {
        $startScript = Join-Path $root 'PowerShellEditorServices/Start-EditorServices.ps1'
        $version = Get-PsesBundleVersion $root
        if ($version -and (Test-Path $startScript)) {
            [pscustomobject]@{ Version = $version; Root = $root; StartScript = $startScript }
        }
    }
}

function Get-PsesStartScript {
    # Pinned: only that exact version qualifies. Otherwise: newest installed.
    $installed = @(Get-PsesInstalled)
    $pin = Get-PsesPinnedVersion
    if ($pin) { $installed = @($installed | Where-Object Version -EQ $pin) }
    $best = $installed | Sort-Object Version -Descending | Select-Object -First 1
    if ($best) { return $best.StartScript }
    return $null
}

function Test-PsesAnalyzer {
    # PSES publishes no diagnostics at all (and logs nothing) when its bundled
    # PSScriptAnalyzer can't load in the running pwsh, e.g. PSScriptAnalyzer 1.25.0
    # on PowerShell older than 7.4.6. Returns the load error, or $null when it loads.
    param([string]$StartScript)
    $module = Join-Path (Split-Path (Split-Path $StartScript)) 'PSScriptAnalyzer'
    if (-not (Test-Path $module)) { return "PSScriptAnalyzer is missing from $(Split-Path $module)" }
    try {
        Import-Module $module -ErrorAction Stop
        return $null
    }
    catch { return $_.Exception.Message }
}

function Get-PsesLatestVersion {
    # Reads the tag GitHub redirects /releases/latest to. $null when it can't be
    # determined (offline, curl missing) — callers treat that as "no update".
    $curl = Get-Command curl -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $curl) { return $null }
    $location = & $curl.Source -sI --max-time 10 "$script:PsesRepoUrl/releases/latest" 2>$null |
        Where-Object { $_ -match '^location:' } | Select-Object -First 1
    if ($location -match '/tag/v?(\d+\.\d+\.\d+)\s*$') { return [version]$Matches[1] }
    return $null
}

function Test-PsesUpdateAvailable {
    # Only when tracking latest from the default source, and at most once per
    # $PsesUpdateCheckHours. A pin, mirror URL or local zip never auto-updates.
    if ((Get-PsesPinnedVersion) -or $env:CLAUDE_PSES_URL -or $env:CLAUDE_PSES_ZIP) { return $false }
    $stamp = Join-Path (Get-PsesCacheDir) 'last-update-check'
    if ((Test-Path $stamp) -and (Get-Item $stamp).LastWriteTime -gt (Get-Date).AddHours(-$script:PsesUpdateCheckHours)) { return $false }
    $latest = Get-PsesLatestVersion
    if (-not $latest) { return $false }
    Set-Content -Path $stamp -Value "$latest"
    $newest = Get-PsesInstalled | Sort-Object Version -Descending | Select-Object -First 1
    return (-not $newest) -or ($latest -gt $newest.Version)
}

function Remove-PsesStaleVersions {
    # Keeps the two newest installs (a session started before an update may still
    # be running the previous one). Nothing is removed while a version is pinned.
    if (Get-PsesPinnedVersion) { return }
    Get-PsesInstalled | Sort-Object Version -Descending | Select-Object -Skip 2 |
        ForEach-Object { Remove-Item -Recurse -Force $_.Root -ErrorAction SilentlyContinue }
}

function Get-PsesZip {
    param([string]$Destination)
    # 1. Explicit local zip (air-gapped / corporate mirror installs)
    if ($env:CLAUDE_PSES_ZIP -and (Test-Path $env:CLAUDE_PSES_ZIP)) {
        Copy-Item $env:CLAUDE_PSES_ZIP $Destination -Force
        return
    }
    $url = Get-PsesReleaseUrl
    # 2. curl first (ships with macOS, Windows 10+, and most Linux distros;
    #    endpoint-security tools that block .NET networking usually allow it)
    $curl = Get-Command curl -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($curl) {
        & $curl.Source -sfL --max-time 300 -o $Destination $url
        if ($LASTEXITCODE -eq 0 -and (Test-Path $Destination)) { return }
    }
    # 3. Invoke-WebRequest fallback, with a hard timeout so a blocked network
    #    fails fast instead of hanging the LSP startup
    try {
        $oldProgress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $Destination -MaximumRedirection 5 -TimeoutSec 120
        return
    }
    catch { }
    finally { $ProgressPreference = $oldProgress }
    throw "Could not download PowerShell Editor Services from $url (network blocked, or no such release?). Set CLAUDE_PSES_ZIP to a local copy of PowerShellEditorServices.zip and retry."
}

function Install-Pses {
    # Quiet by design: when called from the LSP launch path, stdout belongs to the
    # LSP protocol stream and must not be polluted.
    $cacheDir = Get-PsesCacheDir
    $pin = Get-PsesPinnedVersion
    $zipPath = Join-Path ([IO.Path]::GetTempPath()) "pses-download-$PID.zip"
    $staging = Join-Path $cacheDir "staging-$PID"
    try {
        New-Item -ItemType Directory -Path (Join-Path $cacheDir 'versions') -Force | Out-Null
        Get-PsesZip -Destination $zipPath
        if ($env:CLAUDE_PSES_SHA256) {
            $actual = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
            if ($actual -ne $env:CLAUDE_PSES_SHA256.Trim()) {
                throw "PowerShell Editor Services download failed SHA-256 verification (expected $($env:CLAUDE_PSES_SHA256.Trim()), got $actual)."
            }
        }
        if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
        Expand-Archive -Path $zipPath -DestinationPath $staging -Force
        $version = Get-PsesBundleVersion $staging
        if (-not $version) { throw "PowerShell Editor Services install failed: no module manifest in the downloaded archive." }
        if ($pin -and $version -ne $pin) {
            throw "CLAUDE_PSES_VERSION pins $pin but the downloaded archive is $version (check CLAUDE_PSES_URL / CLAUDE_PSES_ZIP)."
        }
        $target = Join-Path $cacheDir "versions/$version"
        if (Test-Path $target) { Remove-Item -Recurse -Force $target }
        Move-Item -Path $staging -Destination $target
    }
    finally {
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
    }
    $startScript = Get-PsesStartScript
    if (-not $startScript) { throw "PowerShell Editor Services install failed: Start-EditorServices.ps1 not found under $cacheDir" }
    return $startScript
}
