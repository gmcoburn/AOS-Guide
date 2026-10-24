#!/usr/bin/env bash
# PreToolUse hook for Bash. Blocks commands that AGENTS.md forbids.
# Claude Code passes the tool call as JSON on stdin. Exit 2 blocks the call and
# sends stderr back to Claude. This is a tripwire, not a sandbox: the dev container
# is the real boundary.
input="$(cat)"

block() {
  echo "Blocked by .claude/hooks/guard-bash.sh: $1. Ask the human to run it if it is really needed." >&2
  exit 2
}

# Downloaded script piped into a shell
echo "$input" | grep -Eq '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da)?sh([^[:alnum:]]|$)' \
  && block "piping a download into a shell"

# Privilege escalation
echo "$input" | grep -Eq '(^|[^[:alnum:]_-])sudo[[:space:]]' && block "sudo"

# Recursive delete of root, home, or parent directories
echo "$input" | grep -Eq 'rm[[:space:]]+(-[[:alpha:]]+[[:space:]]+)*-[[:alpha:]]*[rR][[:alpha:]]*[[:space:]]+(-[[:alpha:]]+[[:space:]]+)*(/|~|\$HOME|\.\.)(/?\*?)([[:space:]]|\\?"|$)' \
  && block "recursive delete outside the project"

# Force push (allow --force-with-lease)
echo "$input" | grep -Eq 'git[[:space:]]+push[^"]*[[:space:]](--force|-f)([[:space:]]|\\?"|$)' \
  && block "git push --force"

exit 0
