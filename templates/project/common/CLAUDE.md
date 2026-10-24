@AGENTS.md

## Claude Code notes

- Shared permissions and hooks live in `.claude/settings.json`. Put personal overrides in
  `.claude/settings.local.json` (git-ignored).
- For work on Confidential data, start the session with `./scripts/claude-onprem.sh` instead of `claude`.
