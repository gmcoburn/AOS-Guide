# AOS-Guide

A personal "agentic engineering OS": conventions, a project template and scripts for
using Claude Code, Cursor, OpenAI Codex, an on-prem Anthropic-compatible AI service and
third-party AI APIs together on the same codebase, with projects hosted on GitHub or
Azure DevOps.

New here? Read [docs/GETTING-STARTED.md](docs/GETTING-STARTED.md): a plain-English guide to
setting it up and the everyday workflow.

For the full design, see [docs/HANDOFF.md](docs/HANDOFF.md): the design, decisions, corrections to the
earlier draft, open questions, and a review brief for another AI.

## Layout

| Path | What |
|---|---|
| `docs/HANDOFF.md` | Design and decision record |
| `templates/project/common` | Files every project gets |
| `templates/project/github` | Extra files for GitHub projects |
| `templates/project/azure-devops` | Extra files for Azure DevOps projects |
| `templates/personal/AGENTS.md` | Starting point for your personal rules (shared by every project) |
| `bin/New-AgenticProject.ps1` | Create a project from the template |
| `bin/AgenticOS.psm1` | PowerShell helpers (`New-AgenticProject`, `claude-onprem`) |
| `gateway/` | Optional LiteLLM gateway for the on-prem and third-party APIs |
| `server/` | Ubuntu Docker host setup and the agent egress firewall |

## Create a project

From PowerShell 7 (`pwsh`) on the Ubuntu dev server, where the dev containers run:

```powershell
Import-Module ~/src/AOS-Guide/bin/AgenticOS.psm1
New-AgenticProject -Name my-tool -Platform GitHub -Path ~/src -CreateRemote
# Company work: org URL and project come from $env:AOS_ADO_ORG_URL / $env:AOS_ADO_PROJECT
New-AgenticProject -Name my-svc -Platform AzureDevOps -Path ~/src -CreateRemote
```

Then in Cursor on Windows: Remote-SSH to the server, open the folder, and choose
**Reopen in Container**. The server needs the one-off setup in [server/README.md](server/README.md).

## Public repo rule

This repository is public. Never commit hostnames, IP addresses, tokens, or internal
names. Use placeholders and environment variables.
