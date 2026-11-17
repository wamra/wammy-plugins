# powershell-lsp — PowerShell language server for Claude Code

Gives Claude Code semantic code intelligence for PowerShell (`.ps1`, `.psm1`, `.psd1`) via Microsoft's official [PowerShell Editor Services](https://github.com/PowerShell/PowerShellEditorServices) (PSES) — the same language server behind the VS Code PowerShell extension.

Instead of grepping, Claude can use the built-in `LSP` tool for:

- **goToDefinition** — including cross-file: calls into modules (`.psm1`) and dot-sourced scripts resolve to their definitions
- **findReferences** — across the whole workspace
- **hover** — signatures and docs
- **documentSymbol** — outline of functions/variables in a file
- **workspaceSymbol** — find a function by name across the workspace
- **rename** — LSP rename support (PSES rename is best-effort; review edits)

PSES also publishes diagnostics from its bundled PSScriptAnalyzer, provided PSScriptAnalyzer loads in your `pwsh` (see Requirements).

## Requirements

- **PowerShell 7+** (`pwsh`) on PATH — [install instructions](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- **PowerShell 7.4.6+ for diagnostics** — the PSScriptAnalyzer bundled with current PSES releases does not load in older versions; navigation still works, but no diagnostics are published. The `SessionStart` hook prints a warning when this is the case.
- Claude Code **2.1.50+** (uses modern `.lsp.json` fields like `startupTimeout`)
- macOS, Linux, or Windows

That's it. **PSES itself is installed automatically**: a `SessionStart` hook downloads the official release zip (~20 MB) into a platform cache directory:

| OS | Cache location |
|---|---|
| macOS | `~/Library/Caches/claude-powershell-lsp` |
| Linux | `$XDG_CACHE_HOME/claude-powershell-lsp` (or `~/.cache/...`) |
| Windows | `%LOCALAPPDATA%\claude-powershell-lsp` |

The download prefers `curl` (endpoint-security tools often block .NET networking while allowing curl) and falls back to `Invoke-WebRequest`. If the session-start install didn't run, the LSP launcher installs on first use instead.

## PSES version

By default the plugin tracks the **latest** PSES release: the `SessionStart` hook checks GitHub at most once every 24 hours and installs a newer release when there is one. Each release is unpacked into its own `versions/<version>` directory, so an update never touches a language server that is already running; the two newest are kept.

To pin a release, set `CLAUDE_PSES_VERSION`:

```bash
export CLAUDE_PSES_VERSION=4.7.0   # or v4.7.0; unset or "latest" to track the newest
```

While pinned, only that exact version is used (it is downloaded if missing), no update checks are made, and nothing is pruned. Add `CLAUDE_PSES_SHA256` to also verify the downloaded zip. Update checks are also skipped when `CLAUDE_PSES_URL` or `CLAUDE_PSES_ZIP` is set.

## Install

```bash
claude plugin marketplace add wamra/wammy-plugins
claude plugin install powershell-lsp@wammy-plugins
```

Restart Claude Code (plugins and their LSP servers load at session start), then open any `.ps1` file context and ask Claude to find references or definitions.

## Environment overrides

| Variable | Purpose |
|---|---|
| `CLAUDE_PSES_VERSION` | Pin an exact PSES release (e.g. `4.7.0`); unset or `latest` tracks the newest |
| `CLAUDE_PSES_SHA256` | Expected SHA-256 of the PSES zip; the install fails on a mismatch |
| `CLAUDE_PSES_PATH` | Use a custom PSES install/cache directory |
| `CLAUDE_PSES_URL` | Download PSES from a mirror instead of GitHub releases |
| `CLAUDE_PSES_ZIP` | Air-gapped installs: path to a local `PowerShellEditorServices.zip` |

## Known limitations (inherited from PSES)

- No call hierarchy (`incomingCalls`/`outgoingCalls` have no provider)
- Aliases (`Set-Alias`) don't resolve to their target function
- Dynamic invocation (`& $cmdName`, `Invoke-Expression`) is not statically resolved
- Cross-file rename is best-effort — always review the edit set

## Troubleshooting

- **"No LSP server available for file type: .ps1"** — the plugin loads at session start; restart Claude Code after installing.
- **First call slow / "server is starting"** — PSES startup takes a few seconds (longer on first-ever run while downloading); retry.
- **No diagnostics** — check the `SessionStart` hook output for "diagnostics are off"; on PowerShell older than 7.4.6 the bundled PSScriptAnalyzer fails to load and PSES stays silent. Update PowerShell.
- **Logs** — `pses-claude-<pid>.log` in your temp directory.
- **Corporate networks** — if both curl and Invoke-WebRequest are blocked, download [PowerShellEditorServices.zip](https://github.com/PowerShell/PowerShellEditorServices/releases/latest) manually and set `CLAUDE_PSES_ZIP` to its path.

## License

MIT (this plugin). PowerShell Editor Services is © Microsoft, MIT-licensed, downloaded from its official releases at install time — not redistributed here.
