#!/usr/bin/env bash
# The one verification command for this project. Used by humans, every AI agent, and CI.
# Replace the TODO lines with this stack's lint and test commands.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> lint"
# TODO e.g. npm run lint | ruff check . | dotnet format --verify-no-changes

echo "==> test"
# TODO e.g. npm test | pytest | dotnet test

echo "check.sh: no lint or test commands configured yet" >&2
