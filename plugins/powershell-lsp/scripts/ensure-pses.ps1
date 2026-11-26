#Requires -Version 7
# SessionStart hook: pre-installs PowerShell Editor Services so the first LSP
# call doesn't pay the download cost, and (when no version is pinned) picks up
# new releases. Prints a short status line (hook output is allowed to be
# chatty; the LSP launch path is not).
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pses-common.ps1')

function Get-ReadyText($script) {
    $v = Get-PsesInstalled | Where-Object StartScript -EQ $script | Select-Object -First 1 -ExpandProperty Version
    if ($v) { "PowerShell Editor Services $v" } else { 'PowerShell Editor Services' }
}

$startScript = $null
try {
    $startScript = Get-PsesStartScript
    if (-not $startScript) {
        Write-Output 'powershell-lsp: downloading PowerShell Editor Services...'
        $startScript = Install-Pses
        Set-PsesUpdateStamp
    }
    elseif (Test-PsesUpdateAvailable) {
        Write-Output 'powershell-lsp: updating PowerShell Editor Services...'
        $startScript = Install-Pses
        Set-PsesUpdateStamp
    }
    Remove-PsesStaleVersions
    Write-Output "powershell-lsp: $(Get-ReadyText $startScript) ready"
    $analyzerError = Test-PsesAnalyzer $startScript
    if ($analyzerError) {
        Write-Output (Format-PsesText "powershell-lsp: diagnostics are off — PSScriptAnalyzer does not load in PowerShell $($PSVersionTable.PSVersion): $analyzerError")
    }
}
catch {
    $msg = Format-PsesText ($_.Exception.Message -replace '\s+', ' ')
    if ($startScript) {
        Write-Output "powershell-lsp: update failed ($msg). Keeping $(Get-ReadyText $startScript)."
    }
    else {
        Write-Output "powershell-lsp: install failed ($msg). The language server will retry on first use."
    }
}
exit 0  # never block the session
