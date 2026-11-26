# wammy-plugins

Claude Code plugin marketplace by [wamra](https://github.com/wamra).

## Install

```bash
claude plugin marketplace add wamra/wammy-plugins
claude plugin install powershell-lsp@wammy-plugins
```

`powershell-lsp` is hosted in this repository and installable by anyone. The marketplace manifest also lists `session-index`, `code-index-search` and `specs-index`; their source repositories have not been published yet, so installing them will fail until the owner publishes them. They are listed here so the names and commands are stable:

```bash
claude plugin install session-index@wammy-plugins
claude plugin install code-index-search@wammy-plugins
claude plugin install specs-index@wammy-plugins
```

Restart Claude Code after installing (plugins and their LSP servers load at session start).

## Plugins

| Plugin | What it does | Availability |
|---|---|---|
| [`powershell-lsp`](plugins/powershell-lsp) | PowerShell language server (Microsoft PSES): cross-file go-to-definition, find-references, hover, rename for `.ps1`/`.psm1`/`.psd1`. Downloads PSES on first run. macOS / Linux / Windows. | Installable now |
| `session-index` | Hooks that keep a lossless, searchable archive of your Claude Code sessions, a search skill, `search` and `show` tools and a `/sessions` command. Binaries bundled. | Not yet published |
| `code-index-search` | `search` and `show` tools, a `/code` command and a skill over a repo's semantic code index. Binaries bundled. | Not yet published |
| `specs-index` | Index of your BRD, FDS and Gherkin specs: search, requirement traceability, coverage gaps. Binaries bundled. | Not yet published |

## Layout

```
.claude-plugin/marketplace.json   # marketplace manifest
plugins/<name>/                   # one directory per plugin
```

## Security and contributing

See [SECURITY.md](SECURITY.md) and [CONTRIBUTING.md](CONTRIBUTING.md). Third-party components are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

MIT
