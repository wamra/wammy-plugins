# powershell-lsp — PowerShell language server for Claude Code

Gives Claude Code semantic code intelligence for PowerShell (`.ps1`, `.psm1`, `.psd1`) via Microsoft's official [PowerShell Editor Services](https://github.com/PowerShell/PowerShellEditorServices) (PSES) — the same language server behind the VS Code PowerShell extension.

Instead of grepping, Claude can use the built-in `LSP` tool for:

- **goToDefinition** — including cross-file: calls into modules (`.psm1`) and dot-sourced scripts resolve to their definitions
- **findReferences** — across the whole workspace
- **hover** — signatures and docs
- **documentSymbol** — outline of functions/variables in a file
- **rename** — LSP rename support (PSES rename is best-effort; review edits)

Diagnostics from the bundled PSScriptAnalyzer are pushed into Claude's context automatically.

## Requirements

- **PowerShell 7+** (`pwsh`) on PATH — [install instructions](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- Claude Code **2.1.50+** (uses modern `.lsp.json` fields like `startupTimeout`)
- macOS, Linux, or Windows

That's it. **PSES itself is installed automatically**: a `SessionStart` hook downloads the official release zip (~20 MB, one time) into a platform cache directory:

| OS | Cache location |
|---|---|
| macOS | `~/Library/Caches/claude-powershell-lsp` |
| Linux | `$XDG_CACHE_HOME/claude-powershell-lsp` (or `~/.cache/...`) |
| Windows | `%LOCALAPPDATA%\claude-powershell-lsp` |

The download prefers `curl` (endpoint-security tools often block .NET networking while allowing curl) and falls back to `Invoke-WebRequest`. If the session-start install didn't run, the LSP launcher installs on first use instead.

## Install

```bash
claude plugin marketplace add wamra/wammy-plugins
claude plugin install powershell-lsp@wammy-plugins
```

Restart Claude Code (plugins and their LSP servers load at session start), then open any `.ps1` file context and ask Claude to find references or definitions.

## Environment overrides

| Variable | Purpose |
|---|---|
| `CLAUDE_PSES_PATH` | Use a custom PSES install/cache directory |
| `CLAUDE_PSES_URL` | Download PSES from a mirror instead of GitHub releases |
| `CLAUDE_PSES_ZIP` | Air-gapped installs: path to a local `PowerShellEditorServices.zip` |

## Known limitations (inherited from PSES)

- No call hierarchy (`incomingCalls`/`outgoingCalls` have no provider)
- No workspace-wide symbol search (`workspaceSymbol`)
- Aliases (`Set-Alias`) don't resolve to their target function
- Dynamic invocation (`& $cmdName`, `Invoke-Expression`) is not statically resolved
- Cross-file rename is best-effort — always review the edit set

## Troubleshooting

- **"No LSP server available for file type: .ps1"** — the plugin loads at session start; restart Claude Code after installing.
- **First call slow / "server is starting"** — PSES startup takes a few seconds (longer on first-ever run while downloading); retry.
- **Logs** — `pses-claude-<pid>.log` in your temp directory.
- **Corporate networks** — if both curl and Invoke-WebRequest are blocked, download [PowerShellEditorServices.zip](https://github.com/PowerShell/PowerShellEditorServices/releases/latest) manually and set `CLAUDE_PSES_ZIP` to its path.

## License

MIT (this plugin). PowerShell Editor Services is © Microsoft, MIT-licensed, downloaded from its official releases at install time — not redistributed here.
