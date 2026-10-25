@AGENTS.md

## Claude Code notes

- Shared permissions and hooks live in `.claude/settings.json`. Put personal overrides in
  `.claude/settings.local.json` (git-ignored).
- To use the on-prem model instead of the Team plan, start the session with `./scripts/claude-onprem.sh` instead of `claude`.
