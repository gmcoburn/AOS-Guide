# AOS-Guide

A personal "agentic engineering OS": conventions, a project template and scripts for
using Claude Code, Cursor, OpenAI Codex, an on-prem Anthropic-compatible AI service and
third-party AI APIs together on the same codebase, with projects hosted on GitHub or
Azure DevOps.

Start with [docs/HANDOFF.md](docs/HANDOFF.md): the design, decisions, corrections to the
earlier draft, open questions, and a review brief for another AI.

## Layout

| Path | What |
|---|---|
| `docs/HANDOFF.md` | Design and decision record |
| `templates/project/common` | Files every project gets |
| `templates/project/github` | Extra files for GitHub projects |
| `templates/project/azure-devops` | Extra files for Azure DevOps projects |
| `bin/New-AgenticProject.ps1` | Create a project from the template |
| `bin/AgenticOS.psm1` | PowerShell helpers (`New-AgenticProject`, `claude-onprem`) |
| `gateway/` | Optional LiteLLM gateway for the on-prem and third-party APIs |

## Create a project

From PowerShell 7 in WSL2 (keeps code on the fast Linux filesystem):

```powershell
Import-Module ~/src/AOS-Guide/bin/AgenticOS.psm1
New-AgenticProject -Name my-tool -Platform GitHub -Path ~/src -CreateRemote
New-AgenticProject -Name my-svc -Platform AzureDevOps -Path ~/src -CreateRemote `
    -AdoOrganization <org> -AdoProject <project>
```

Then open the folder in Cursor and choose **Reopen in Container**.

## Public repo rule

This repository is public. Never commit hostnames, IP addresses, tokens, or internal
names. Use placeholders and environment variables.
