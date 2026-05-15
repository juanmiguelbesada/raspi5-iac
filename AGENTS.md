- Never commit or push without explicit permission.

- Keep it minimal — only add what's needed, no premature extras.

- Default unless specified, needed, or known bad-practice — applies to
everything: configuration flags, dependencies, tools, and patterns.
Restore defaults before turning it back off.

- Use conventional commits: `type(scope): description` (e.g. `feat(ansible): ...`).
  Scope is optional — omit it when changes span multiple areas.
  Valid scopes: `ansible`, `terraform`, `argocd`, `cloudflare`, `apps`, `docs`, `makefile`, `misc`.

- Don't set any config value that matches its default — skip it entirely.

- Use Context7 MCP to fetch latest docs for any library, framework, CLI tool,
or cloud service — don't rely on training data for API syntax or setup steps.

- Docs code snippets should include useful inline comments explaining what each
part does.

- Work through pull requests: create a branch, push, open a PR, and request
  review. Never commit or push directly to main.
