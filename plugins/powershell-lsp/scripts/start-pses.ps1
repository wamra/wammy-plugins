#Requires -Version 7
# LSP entry point: locates (downloading on first use) PowerShell Editor Services
# and starts it in stdio mode. stdout is the LSP protocol stream — nothing else
# may be written to it.
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pses-common.ps1')

$startScript = Get-PsesStartScript
if (-not $startScript) { $startScript = Install-Pses }

$tmp = [IO.Path]::GetTempPath()
$bundleRoot = Split-Path (Split-Path $startScript)

& $startScript `
    -BundledModulesPath $bundleRoot `
    -LogPath (Join-Path $tmp "pses-claude-$PID.log") `
    -SessionDetailsPath (Join-Path $tmp "pses-claude-session-$PID.json") `
    -LogLevel Warning `
    -HostName 'ClaudeCode' `
    -HostProfileId 'ClaudeCode' `
    -HostVersion '1.0.0' `
    -Stdio
