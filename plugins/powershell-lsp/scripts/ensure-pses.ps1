#Requires -Version 7
# SessionStart hook: pre-installs PowerShell Editor Services so the first LSP
# call doesn't pay the download cost. Prints a short status line (hook output
# is allowed to be chatty; the LSP launch path is not).
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pses-common.ps1')

$startScript = Get-PsesStartScript
if ($startScript) {
    Write-Output "powershell-lsp: PowerShell Editor Services ready ($startScript)"
    exit 0
}

Write-Output 'powershell-lsp: downloading PowerShell Editor Services (first run)...'
try {
    $startScript = Install-Pses
    Write-Output "powershell-lsp: installed to $startScript"
}
catch {
    Write-Output "powershell-lsp: install failed — $($_.Exception.Message). PowerShell LSP will retry on first use."
    exit 0  # never block the session
}
