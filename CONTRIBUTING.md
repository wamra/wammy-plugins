# Contributing

Issues and pull requests are welcome.

- Keep changes small and focused; one logical change per commit, with a plain imperative message.
- Plugin changes live under `plugins/<name>/`. Update that plugin's README and the version in both `plugin.json` and `.claude-plugin/marketplace.json` when behavior changes.
- Run `claude plugin validate .` before opening a pull request. CI also installs the plugin on Linux, macOS and Windows.
- Do not include personal data, credentials or machine-specific paths.
- Report security issues privately, as described in [SECURITY.md](SECURITY.md).

By contributing you agree that your contribution is licensed under the MIT license in [LICENSE](LICENSE).
