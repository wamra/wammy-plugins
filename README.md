# wammy-plugins

Claude Code plugin marketplace by [wamra](https://github.com/wamra).

## Install

```bash
claude plugin marketplace add wamra/wammy-plugins
claude plugin install powershell-lsp@wammy-plugins
claude plugin install bash-lsp@wammy-plugins
claude plugin install session-index@wammy-plugins
claude plugin install code-index-search@wammy-plugins
claude plugin install specs-index@wammy-plugins
```

`powershell-lsp` is hosted in this repository. The other plugins install from the `plugin` branch of their own public repositories.

Restart Claude Code after installing (plugins and their LSP servers load at session start).

## Plugins

| Plugin | What it does | Availability |
|---|---|---|
| [`powershell-lsp`](plugins/powershell-lsp) | PowerShell language server (Microsoft PSES): cross-file go-to-definition, find-references, hover, rename for `.ps1`/`.psm1`/`.psd1`. Downloads PSES on first run. macOS / Linux / Windows. | Installable now |
| [`bash-lsp`](https://github.com/wamra/bash-lsp) | Bash language server: definition, references, rename that refuses when it cannot prove safety, call hierarchy, hover, completion and diagnostics for `.sh`/`.bash`/`.bats`/`.ksh`. Reads scripts and never runs them. Binaries bundled. | Installable now |
| [`session-index`](https://github.com/wamra/session-index) | Hooks that keep a lossless, searchable archive of your Claude Code sessions, a search skill, `search` and `show` tools and a `/sessions` command. Binaries bundled. | Installable now |
| [`code-index-search`](https://github.com/wamra/code-index) | `search` and `show` tools, a `/code` command and a skill over a repo's semantic code index. Binaries bundled. | Installable now |
| [`specs-index`](https://github.com/wamra/specs-index) | Index of your BRD, FDS and Gherkin specs: search, requirement traceability, coverage gaps. Binaries bundled. | Installable now |

## Layout

```
.claude-plugin/marketplace.json   # marketplace manifest
plugins/<name>/                   # one directory per plugin
```

## Security and contributing

See [SECURITY.md](SECURITY.md) and [CONTRIBUTING.md](CONTRIBUTING.md). Third-party components are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

MIT
