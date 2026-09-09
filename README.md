# wammy-plugins

Claude Code plugin marketplace by [wamra](https://github.com/wamra).

## Install

```bash
claude plugin marketplace add wamra/wammy-plugins
claude plugin install powershell-lsp@wammy-plugins
```

Restart Claude Code after installing (plugins and their LSP servers load at session start).

## Plugins

| Plugin | What it does |
|---|---|
| [`powershell-lsp`](plugins/powershell-lsp) | PowerShell language server (Microsoft PSES) — cross-file go-to-definition, find-references, hover, rename for `.ps1`/`.psm1`/`.psd1`. Auto-downloads PSES on first run. macOS / Linux / Windows. |

## Layout

```
.claude-plugin/marketplace.json   # marketplace manifest
plugins/<name>/                   # one directory per plugin
```

## License

MIT
