# Security policy

## Reporting a vulnerability

Please report security issues privately through GitHub: open the repository's **Security** tab and choose **Report a vulnerability** (private vulnerability reporting). Do not open a public issue for a suspected vulnerability.

Include the plugin name and version, what you observed, and steps to reproduce. You can expect an acknowledgement and a follow-up on the fix or on why the report is out of scope.

## Scope

This repository holds the marketplace manifest and the `powershell-lsp` plugin. `powershell-lsp` downloads Microsoft PowerShell Editor Services from its GitHub releases and verifies the zip against the SHA-256 that GitHub publishes for the asset; see `plugins/powershell-lsp/README.md` for the exact trust model. Vulnerabilities in PowerShell Editor Services itself should be reported to that project.
