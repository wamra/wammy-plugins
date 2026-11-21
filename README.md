# wammy-plugins

Claude Code plugin marketplace by [wamra](https://github.com/wamra).

## Install

```bash
claude plugin marketplace add wamra/wammy-plugins
claude plugin install powershell-lsp@wammy-plugins
claude plugin install session-index@wammy-plugins
claude plugin install code-index-search@wammy-plugins
```

Restart Claude Code after installing (plugins and their LSP servers load at session start).

## Plugins

| Plugin | What it does |
|---|---|
| [`powershell-lsp`](plugins/powershell-lsp) | PowerShell language server (Microsoft PSES) — cross-file go-to-definition, find-references, hover, rename for `.ps1`/`.psm1`/`.psd1`. Auto-downloads PSES on first run. macOS / Linux / Windows. |
| [`session-index`](https://github.com/wamra/session-index) | Hooks that keep a lossless, searchable archive of your Claude Code sessions, a search skill, `search` and `show` tools and a `/sessions` command. Binaries bundled. |
| [`code-index-search`](https://github.com/wamra/code-index) | `search` and `show` tools, a `/code` command and a skill over a repo's semantic code index. Binaries bundled. |

## Layout

```
.claude-plugin/marketplace.json   # marketplace manifest
plugins/<name>/                   # one directory per plugin
```

## License

MIT
