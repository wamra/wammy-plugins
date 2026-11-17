#Requires -Version 7
# SessionStart hook: pre-installs PowerShell Editor Services so the first LSP
# call doesn't pay the download cost, and (when no version is pinned) picks up
# new releases. Prints a short status line (hook output is allowed to be
# chatty; the LSP launch path is not).
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pses-common.ps1')

$startScript = $null
try {
    $startScript = Get-PsesStartScript
    if (-not $startScript) {
        Write-Output 'powershell-lsp: downloading PowerShell Editor Services...'
        $startScript = Install-Pses
    }
    elseif (Test-PsesUpdateAvailable) {
        Write-Output 'powershell-lsp: updating PowerShell Editor Services...'
        $startScript = Install-Pses
    }
    Remove-PsesStaleVersions
    Write-Output "powershell-lsp: PowerShell Editor Services ready ($startScript)"
    $analyzerError = Test-PsesAnalyzer $startScript
    if ($analyzerError) {
        Write-Output "powershell-lsp: diagnostics are off — PSScriptAnalyzer does not load in PowerShell $($PSVersionTable.PSVersion): $analyzerError"
    }
}
catch {
    if ($startScript) {
        Write-Output "powershell-lsp: update failed — $($_.Exception.Message). Keeping $startScript."
    }
    else {
        Write-Output "powershell-lsp: install failed — $($_.Exception.Message). PowerShell LSP will retry on first use."
    }
}
exit 0  # never block the session
