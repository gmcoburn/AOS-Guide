#!/usr/bin/env bash
# Starts Claude Code against the on-prem Anthropic-compatible service (or the gateway)
# instead of Anthropic's cloud. Use for Confidential projects.
# Needs AOS_ONPREM_URL and AOS_ONPREM_API_KEY; AOS_ONPREM_MODEL is optional.
# The dev container forwards these from the server user's environment (devcontainer.json).
set -euo pipefail

: "${AOS_ONPREM_URL:?Set AOS_ONPREM_URL to the on-prem Anthropic API base URL}"
: "${AOS_ONPREM_API_KEY:?Set AOS_ONPREM_API_KEY to your on-prem API key}"

export ANTHROPIC_BASE_URL="$AOS_ONPREM_URL"
# The on-prem service authenticates with an API key (x-api-key header).
export ANTHROPIC_API_KEY="$AOS_ONPREM_API_KEY"
unset ANTHROPIC_AUTH_TOKEN
if [[ -n "${AOS_ONPREM_MODEL:-}" ]]; then
  export ANTHROPIC_MODEL="$AOS_ONPREM_MODEL"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="${AOS_ONPREM_FAST_MODEL:-$AOS_ONPREM_MODEL}"
fi
# Keep telemetry, error reports and update checks from leaving the network.
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

exec claude "$@"
