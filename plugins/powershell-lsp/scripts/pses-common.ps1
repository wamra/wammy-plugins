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
    $location = & $curl.Source -sI --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 10 "$script:PsesRepoUrl/releases/latest" 2>$null |
        Where-Object { $_ -match '^location:' } | Select-Object -First 1
    if ($location -match '/tag/v?(\d+\.\d+\.\d+)\s*$') { return [version]$Matches[1] }
    return $null
}

function Set-PsesUpdateStamp {
    # Records that a successful check or install happened, so the next one waits
    # $PsesUpdateCheckHours. Never called after a failed install, so it retries.
    $dir = Get-PsesCacheDir
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Set-Content -Path (Join-Path $dir 'last-update-check') -Value (Get-Date -Format o)
}

function Test-PsesUpdateAvailable {
    # Only when tracking latest from the default source, and at most once per
    # $PsesUpdateCheckHours. A pin, mirror URL or local zip never auto-updates.
    # The stamp is written here only when no update is needed; when one is, the
    # caller writes it after the install succeeds.
    if ((Get-PsesPinnedVersion) -or $env:CLAUDE_PSES_URL -or $env:CLAUDE_PSES_ZIP) { return $false }
    $stamp = Join-Path (Get-PsesCacheDir) 'last-update-check'
    if ((Test-Path $stamp) -and (Get-Item $stamp).LastWriteTime -gt (Get-Date).AddHours(-$script:PsesUpdateCheckHours)) { return $false }
    $latest = Get-PsesLatestVersion
    if (-not $latest) { return $false }
    $newest = Get-PsesInstalled | Sort-Object Version -Descending | Select-Object -First 1
    if ($newest -and $latest -le $newest.Version) { Set-PsesUpdateStamp; return $false }
    return $true
}

function Remove-PsesStaleVersions {
    # Keeps the two newest installs (a session started before an update may still
    # be running the previous one). Nothing is removed while a version is pinned.
    if (Get-PsesPinnedVersion) { return }
    Get-PsesInstalled | Sort-Object Version -Descending | Select-Object -Skip 2 |
        ForEach-Object { Remove-Item -Recurse -Force $_.Root -ErrorAction SilentlyContinue }
}

function Format-PsesText {
    # Keeps absolute home and cache paths out of hook output.
    param([string]$Text)
    foreach ($p in @((Get-PsesCacheDir), $HOME)) {
        if ($p) { $Text = $Text.Replace($p, '~') }
    }
    return $Text
}

function Invoke-PsesHttpGet {
    # HTTPS only. curl first, Invoke-WebRequest as fallback. Returns $true on success.
    param([string]$Url, [string]$OutFile, [int]$CurlSeconds, [int]$FallbackSeconds, [string[]]$Header = @())
    if ($Url -notmatch '^https://') { throw "Refusing to download from a non-HTTPS URL." }
    $curl = Get-Command curl -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($curl) {
        $curlArgs = @('-sfL', '--proto', '=https', '--proto-redir', '=https', '--connect-timeout', '10', '--max-time', "$CurlSeconds", '-o', $OutFile)
        foreach ($h in $Header) { $curlArgs += @('-H', $h) }
        & $curl.Source @curlArgs $Url 2>$null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $OutFile)) { return $true }
    }
    $oldProgress = $ProgressPreference
    try {
        $ProgressPreference = 'SilentlyContinue'
        $headers = @{}
        foreach ($h in $Header) { $k, $v = $h -split ':\s*', 2; $headers[$k] = $v }
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -Headers $headers -MaximumRedirection 5 -TimeoutSec $FallbackSeconds
        return $true
    }
    catch { return $false }
    finally { $ProgressPreference = $oldProgress }
}

function New-PsesTempDir {
    # Unique, unpredictable, owner-only directory for the download.
    $bytes = [byte[]]::new(12)
    [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $name = 'pses-' + ([BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
    $path = Join-Path ([IO.Path]::GetTempPath()) $name
    if (Test-Path $path) { throw "Temporary directory already exists." }
    New-Item -ItemType Directory -Path $path | Out-Null
    if (-not $IsWindows) {
        $chmod = Get-Command chmod -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($chmod) { & $chmod.Source 700 $path }
    }
    return $path
}

function Get-PsesReleaseInfo {
    # Asks the GitHub API for the release (latest, or the pinned tag) and returns
    # its tag and the SHA-256 GitHub publishes in the asset's `digest` field.
    $pin = Get-PsesPinnedVersion
    $api = 'https://api.github.com/repos/PowerShell/PowerShellEditorServices/releases/' + $(if ($pin) { "tags/v$pin" } else { 'latest' })
    $tmp = New-PsesTempDir
    try {
        $file = Join-Path $tmp 'release.json'
        if (-not (Invoke-PsesHttpGet -Url $api -OutFile $file -CurlSeconds 10 -FallbackSeconds 10 -Header @('Accept: application/vnd.github+json'))) {
            throw "Could not read release metadata from the GitHub API (offline, or rate limited). Set CLAUDE_PSES_SHA256 or CLAUDE_PSES_ZIP to install without it."
        }
        $release = Get-Content -Raw $file | ConvertFrom-Json
    }
    finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    if ($release.tag_name -notmatch '^v\d+\.\d+\.\d+$') { throw "Unexpected release tag from the GitHub API." }
    $asset = @($release.assets | Where-Object name -EQ 'PowerShellEditorServices.zip') | Select-Object -First 1
    if (-not $asset -or "$($asset.digest)" -notmatch '^sha256:([0-9a-fA-F]{64})$') {
        throw "GitHub publishes no SHA-256 digest for $($release.tag_name); refusing an unverified download. Set CLAUDE_PSES_SHA256 to override."
    }
    [pscustomobject]@{ Tag = $release.tag_name; Sha256 = $Matches[1].ToUpperInvariant() }
}

function Get-PsesZip {
    param([string]$Destination, [string]$Url)
    # 1. Explicit local zip (air-gapped / corporate mirror installs)
    if ($env:CLAUDE_PSES_ZIP -and (Test-Path $env:CLAUDE_PSES_ZIP)) {
        Copy-Item $env:CLAUDE_PSES_ZIP $Destination -Force
        return
    }
    # 2. curl, then Invoke-WebRequest, both HTTPS-only with hard timeouts so a
    #    blocked or slow network fails fast instead of hanging session start
    if (Invoke-PsesHttpGet -Url $Url -OutFile $Destination -CurlSeconds 45 -FallbackSeconds 20) { return }
    throw "Could not download PowerShell Editor Services (network blocked, or no such release?). Set CLAUDE_PSES_ZIP to a local copy of PowerShellEditorServices.zip and retry."
}

function Assert-PsesZipSafe {
    # Zip-slip guard: every entry must resolve inside the destination.
    param([string]$ZipPath, [string]$Destination)
    $sep = [IO.Path]::DirectorySeparatorChar
    $root = [IO.Path]::GetFullPath($Destination).TrimEnd('/', '\') + $sep
    $cmp = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $zip = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        foreach ($e in $zip.Entries) {
            $full = [IO.Path]::GetFullPath([IO.Path]::Combine($root, $e.FullName))
            if (-not $full.StartsWith($root, $cmp)) { throw "The downloaded archive contains an entry outside the install directory; refusing to extract." }
        }
    }
    finally { $zip.Dispose() }
}

function Enter-PsesLock {
    # Exclusive lock file (CreateNew is atomic). Bounded wait; a lock older than
    # five minutes is treated as left behind by a crashed process.
    param([string]$Dir, [int]$WaitSeconds = 30)
    $path = Join-Path $Dir 'install.lock'
    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    while ($true) {
        try {
            return [IO.File]::Open($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        }
        catch [IO.IOException] {
            $item = Get-Item $path -ErrorAction SilentlyContinue
            if ($item -and $item.LastWriteTime -lt (Get-Date).AddMinutes(-5)) {
                Remove-Item $path -Force -ErrorAction SilentlyContinue
                continue
            }
            if ((Get-Date) -gt $deadline) { throw "Another PowerShell Editor Services install is in progress; try again shortly." }
            Start-Sleep -Milliseconds 500
        }
    }
}

function Exit-PsesLock {
    param($Handle, [string]$Dir)
    if ($Handle) { $Handle.Dispose() }
    Remove-Item (Join-Path $Dir 'install.lock') -Force -ErrorAction SilentlyContinue
}

function Install-Pses {
    # Quiet by design: when called from the LSP launch path, stdout belongs to the
    # LSP protocol stream and must not be polluted.
    $cacheDir = Get-PsesCacheDir
    $pin = Get-PsesPinnedVersion
    New-Item -ItemType Directory -Path (Join-Path $cacheDir 'versions') -Force | Out-Null
    $hadInstall = [bool](Get-PsesStartScript)

    # Integrity: an explicit CLAUDE_PSES_SHA256 wins. A user-supplied zip or URL is
    # trusted as given. Otherwise the digest comes from the GitHub API and the
    # install fails closed when it is missing or does not match.
    $url = Get-PsesReleaseUrl
    $expected = $null
    $targetVersion = $null
    $localZip = $env:CLAUDE_PSES_ZIP -and (Test-Path $env:CLAUDE_PSES_ZIP)
    if ($env:CLAUDE_PSES_SHA256) { $expected = $env:CLAUDE_PSES_SHA256.Trim() }
    elseif (-not $localZip -and -not $env:CLAUDE_PSES_URL) {
        $info = Get-PsesReleaseInfo
        $expected = $info.Sha256
        $targetVersion = [version]$info.Tag.TrimStart('v')
        $url = "$script:PsesRepoUrl/releases/download/$($info.Tag)/PowerShellEditorServices.zip"
    }

    $lock = Enter-PsesLock -Dir $cacheDir
    $tmp = $null
    $staging = Join-Path $cacheDir "staging-$PID"
    try {
        # Another process may have finished the same install while this one waited.
        $existing = Get-PsesInstalled | Where-Object { $targetVersion -and $_.Version -eq $targetVersion } | Select-Object -First 1
        if ($existing) { return $existing.StartScript }
        if (-not $hadInstall -and -not $targetVersion) {
            $already = Get-PsesStartScript
            if ($already) { return $already }
        }

        $tmp = New-PsesTempDir
        $zipPath = Join-Path $tmp 'PowerShellEditorServices.zip'
        Get-PsesZip -Destination $zipPath -Url $url
        if ($expected) {
            $actual = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
            if ($actual -ne $expected) {
                throw "PowerShell Editor Services download failed SHA-256 verification (expected $expected, got $actual)."
            }
        }
        if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
        Assert-PsesZipSafe -ZipPath $zipPath -Destination $staging
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
        if ($tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
        Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
        Exit-PsesLock -Handle $lock -Dir $cacheDir
    }
    $startScript = Get-PsesStartScript
    if (-not $startScript) { throw "PowerShell Editor Services install failed: Start-EditorServices.ps1 not found in the cache." }
    return $startScript
}
