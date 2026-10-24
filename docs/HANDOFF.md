# Agentic OS: Design Handoff for Review

| | |
|---|---|
| Owner | George Coburn |
| Date | 25/10/2026 |
| Status | Draft for independent review. Some items decided, many proposed, several open. |
| Repo | `gmcoburn/AOS-Guide` (public: keep hostnames, IPs, keys and internal names out of it) |

## 0. How to use this document (for the reviewing AI)

You are reviewing the design of a personal "heterogeneous agentic engineering OS": a
set of conventions, project templates, scripts and infrastructure that let one
engineer drive several AI coding tools at once against the same codebase.

Please:

1. Check every item in section 4 ("Corrections") and section 6 onward for factual
   accuracy against **current** vendor documentation. Section 12 lists claims that
   change often and must be re-verified.
2. Look for security gaps, especially around agents that have outbound internet
   access (section 7).
3. Flag anything over-engineered for a single developer.
4. Answer, or sharpen, the open questions in section 11.
5. Review the actual files in this repo (`templates/`, `bin/`, `gateway/`), not just
   this prose.

Do not assume the earlier Google AI design (summarised in section 3) is correct. Much
of it is not.

---

## 1. Goals

- Vibecode productively using several AI tools together, each where it is strongest.
- Use existing paid subscriptions: Claude (Claude Code), Cursor, OpenAI (ChatGPT/Codex).
- Use an on-premises AI service, run by the organisation on its own server, that
  exposes an **Anthropic-compatible API** (Messages API).
- Be able to add other third-party AI services later without rewiring every project.
- A clean, identical file structure for every new project.
- Each project lives in **GitHub or Azure DevOps**, chosen per project.
- Secure and hardened by default: containers where practical.

## 2. Environment and constraints

| Item | Value |
|---|---|
| Workstation | Windows 11 |
| Servers | Ubuntu servers available on the internal network |
| Organisation | Australian business (waste management). Australian date formats and units. Australian Privacy Act 1988 and the APPs apply to personal information. |
| Subscriptions | Claude (plan tier: **open question**), Cursor (tier: open), OpenAI ChatGPT (tier: open) |
| On-prem AI | Anthropic Messages API compatible service. Models, auth method, tool-use and streaming support: **open questions** |
| Repo hosts | GitHub (`gmcoburn` account; org use: open) and Azure DevOps (org/project: open) |

## 3. What the earlier (Google AI) design proposed

Summarised so the reviewer has the full history:

- Treat the setup as an "Agentic OS": Claude Code as "kernel" (files, terminal, git),
  a local reasoning model (DeepSeek-R1) as "reasoning co-processor", Cursor and a fast
  local model (Qwen) for "execution" and autocomplete.
- A root `CLAUDE.md` as the "single source of truth" that both Claude Code and Cursor read.
- `.claude/profiles/*.json` for "kernel" and "remote inference" profiles.
- `.cursor/rules/cursorrules.json` to bind Cursor to the same rules.
- An MCP config using `@modelcontextprotocol/server-everything` with an
  `REMOTE_OLLAMA_ENDPOINT` env var as the "bridge" to the local server.
- A hardened `compose.agentic.yml` (cap_drop ALL, no-new-privileges, tmpfs, internal
  network) as the agent sandbox, optionally with gVisor.
- A PowerShell script that opens an SSH local port forward to Ollama on port 11434.
- A `ufw` script that denies everything except SSH and blocks 11434.
- Workflow: plan with the reasoning model, implement and test with Claude Code, polish
  in Cursor.

## 4. Corrections to the Google design

Each of these is a factual or design problem. The reviewer should confirm or refute.

| # | Google design said | Problem | What we do instead |
|---|---|---|---|
| C1 | `CLAUDE.md` is read by Claude Code **and** Cursor | Cursor does not treat `CLAUDE.md` as its rules file. Cursor reads `AGENTS.md` and `.cursor/rules/*.mdc`. OpenAI Codex reads `AGENTS.md`. | `AGENTS.md` is the cross-tool source of truth. `CLAUDE.md` is a one-line import (`@AGENTS.md`) plus Claude-only notes. Cursor gets a tiny `.mdc` rule pointing at `AGENTS.md`. |
| C2 | `.claude/profiles/kernel-cloud.json`, `remote-inference.json` | Not a Claude Code feature. Claude Code uses `.claude/settings.json` (shared), `.claude/settings.local.json` (personal, git-ignored), `.mcp.json`, `.claude/agents/`, `.claude/skills/`, hooks. | Real `settings.json` with permission allow/ask/deny rules and a `PreToolUse` hook. "Profiles" become launcher functions that set environment variables (`claude-onprem`). |
| C3 | `.cursor/rules/cursorrules.json` with a `rules` array | Wrong format. Cursor project rules are Markdown `.mdc` files with frontmatter (`description`, `globs`, `alwaysApply`). The old single file was `.cursorrules` (deprecated). | `.cursor/rules/00-project.mdc`. |
| C4 | `server-everything` MCP server as the "remote AI bridge" | `server-everything` is a demo/test server. It does not proxy to Ollama or anything else; the env var does nothing. | Talk to models over their HTTP APIs directly, or through a model gateway (section 6.3). Use MCP for **tools** (issue trackers, docs, databases), not as a model transport. |
| C5 | Local DeepSeek-R1 / Qwen via Ollama on port 11434 | The actual on-prem service exposes an **Anthropic-compatible API**, not (necessarily) Ollama. Model names unknown. | Point Anthropic-speaking clients (Claude Code, gateway) at it with `ANTHROPIC_BASE_URL` + token. |
| C6 | Models "must output an architecture map inside `<think>`" | `<think>` tags are a DeepSeek-R1 output quirk, not something to require of every model. | Plans are written to `docs/plans/<date>-<topic>.md` by whichever model plans. Any tool can then implement from the file. |
| C7 | Compose `image: ://microsoft.com` | Invalid image reference. | Dev container on `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`. |
| C8 | `OLLAMA_HOST=http://docker.internal` | The Docker Desktop hostname is `host.docker.internal`. | Not needed; see C5. |
| C9 | `networks: internal: true` | Contradicts the decision that agent containers have internet access (D4). Also blocks package installs. | Normal bridge network with outbound access; risk handled in section 7. |
| C10 | `cap_drop: ALL` then `cap_add: SETUID, SETGID, CHOWN` with `no-new-privileges` | Adding SETUID/SETGID back undoes much of the benefit and is only needed if the container runs as root and switches user. | Run as non-root `vscode` user, `--cap-drop=ALL`, `no-new-privileges`, PID and memory limits. Add individual capabilities back only if something proves it needs them. |
| C11 | Compose file as "the" agent sandbox | Neither Cursor nor Claude Code attaches to an arbitrary compose service by default. | Dev Containers (`.devcontainer/devcontainer.json`): supported by VS Code and Cursor, and Anthropic publishes a reference dev container for Claude Code. Compose is still fine for a project's own services (databases etc.). |
| C12 | gVisor | Practical on an Ubuntu Docker host. Not practical under Docker Desktop on Windows. | Optional, server-side only (phase 3). |
| C13 | `ssh -N -L ...` then check `$LASTEXITCODE` for "tunnel active" | `ssh -N` blocks until the tunnel dies, so the success message never prints while the tunnel is up. | If a tunnel is needed, run it with `Start-Process` or use a mesh VPN (WireGuard/Tailscale). Better: on-prem service and gateway served over internal TLS with token auth, no tunnel. |
| C14 | `ufw deny 11434` protects the container port | **Docker bypasses ufw** for published ports (it writes its own iptables rules). A port published as `-p 11434:11434` is reachable regardless of ufw. | Publish container ports on `127.0.0.1` only, or filter in the `DOCKER-USER` iptables chain. Restrict SSH to the internal subnet, key-only. |
| C15 | `ufw --force reset` script | Running this remotely can drop the SSH session and lock you out. | Change firewall rules manually, from console access, with the SSH allow rule added before enabling. Not scripted in this repo. |
| C16 | "Guardrail" rules in `CLAUDE.md` (no sudo, no `curl \| bash`) | Instructions in a Markdown file are advisory. A model can ignore them, and prompt injection can override them. | Enforce with Claude Code `permissions.deny`, a `PreToolUse` hook, and the container boundary. Markdown rules remain as guidance. |
| C17 | Cloud models via the subscriptions can be routed anywhere | Subscriptions are tied to their first-party clients. A ChatGPT or Claude subscription does **not** come with API credits; a Cursor subscription only works inside Cursor. | Use each subscription through its native client (section 6.1). Only the on-prem service and pay-per-use API keys go through the gateway. |
| C18 | "Cost-free, infinite-token" local reasoning | On-prem compute has real costs and capacity limits, and model quality varies. | Route by task and data sensitivity, not by "free". |

## 5. Decision log

| ID | Decision | Status |
|---|---|---|
| D1 | Windows 11 workstation; Ubuntu servers for shared services | Decided |
| D2 | Use hardened Docker containers and infrastructure where practical | Decided |
| D3 | GitHub **or** Azure DevOps per project, chosen at project creation | Decided |
| D4 | Agent containers have outbound internet access | Decided |
| D5 | Same file structure for every project, generated from `templates/project` | Decided |
| D6 | `AGENTS.md` is the cross-tool instruction file; `CLAUDE.md` imports it | Proposed |
| D7 | Agents run inside a per-project Dev Container, not on the Windows host | Proposed |
| D8 | Source code lives in the WSL2 filesystem (`~/src/...`), not on `C:\` | Proposed |
| D9 | Each subscription is used through its own client; no credential sharing | Proposed |
| D10 | A LiteLLM gateway on an Ubuntu server fronts the on-prem service and any pay-per-use third-party APIs, with per-user/per-project virtual keys | Proposed (phase 2) |
| D11 | One verification command per project: `./scripts/check.sh`, used by humans, every agent, and CI | Proposed |
| D12 | Plans and decisions are files in the repo (`docs/plans/`, `docs/decisions/`), so any tool can pick up another tool's work | Proposed |
| D13 | Secrets never in repos or container images; injected at runtime from a secret store | Proposed |
| D14 | Data classification decides which models may see a project (section 7.3) | Proposed, needs owner input |
| D15 | Every AI-authored change lands via a pull request reviewed by a human | Proposed |

## 6. Target architecture

```
 Windows 11 workstation
 +---------------------------------------------------------------------+
 |  Cursor (IDE)          VS Code (optional)        Windows Terminal   |
 |     |  "Reopen in Container"                          |  wsl         |
 |     v                                                 v              |
 |  WSL2 Ubuntu  ~/src/<project>   (source of truth on local disk)      |
 |     |                                                                |
 |     v  Docker Desktop (WSL2 backend)                                 |
 |  +---------------------------------------------------------------+  |
 |  | Dev Container per project  (non-root, cap-drop ALL,           |  |
 |  | no-new-privileges, pids/memory limits, outbound internet)     |  |
 |  |                                                               |  |
 |  |  claude        -> Anthropic cloud      (Claude subscription)   |  |
 |  |  claude-onprem -> on-prem Anthropic API or gateway (token)     |  |
 |  |  codex         -> OpenAI cloud         (ChatGPT subscription)  |  |
 |  |  git           -> GitHub / Azure DevOps (scoped token)         |  |
 |  +---------------------------------------------------------------+  |
 +---------------------------------------------------------------------+
            |  internal network, TLS, bearer token
            v
 Ubuntu server(s)
 +---------------------------------------------------------------------+
 |  On-prem AI service (Anthropic Messages API)                        |
 |  LiteLLM gateway (phase 2): routes to on-prem + third-party APIs,   |
 |    virtual keys, budgets, logging. Port bound to an internal IP     |
 |    behind TLS; never published on 0.0.0.0 (see C14).                |
 +---------------------------------------------------------------------+
```

### 6.1 Which tool does what

| Tool | Access via | Best used for | Notes |
|---|---|---|---|
| Claude Code | CLI in dev container, Claude subscription login | Multi-file features, refactors, running tests, git work, long autonomous tasks | Reads `CLAUDE.md` (which imports `AGENTS.md`), `.claude/settings.json`, hooks |
| Claude Code on-prem | Same CLI, launched via `scripts/claude-onprem.sh` (sets `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, disables non-essential traffic) | Work on data that must not leave the organisation; bulk/cheap tasks | Depends on the on-prem service supporting streaming and tool use well enough for Claude Code |
| Cursor | Windows app attached to the dev container | Interactive editing, inline completion, UI tweaks, quick questions | Reads `AGENTS.md` and `.cursor/rules/*.mdc` |
| OpenAI Codex | CLI or IDE extension in the dev container, ChatGPT sign-in | Second opinion, independent code review of a branch, parallel tasks | Reads `AGENTS.md` |
| Third-party / API models | LiteLLM gateway (phase 2) | Specialist models, comparisons, scripts that call models directly | Pay-per-use API keys held by the gateway, not by projects |

There is no automatic "router" deciding which model answers. You choose the tool for
the task. What makes the tools cooperate is shared state on disk: `AGENTS.md`, plans
in `docs/plans/`, decisions in `docs/decisions/`, git branches, and one check command.

### 6.2 Typical workflow

1. `New-AgenticProject -Name foo -Platform GitHub` (or `AzureDevOps`) creates the repo
   from the template and optionally the remote.
2. Open the folder in Cursor, "Reopen in Container".
3. Plan: ask any model (Claude, Codex, on-prem) to write
   `docs/plans/2026-10-25-feature-x.md`. Review and edit it.
4. Implement on a branch with Claude Code (or Codex), which runs `./scripts/check.sh`.
5. Polish in Cursor.
6. Optional cross-review: have a *different* vendor's model review the diff.
7. Push, open PR, CI runs the same `./scripts/check.sh` plus a secret scan, human merges.

### 6.3 Model gateway (phase 2)

`gateway/` contains a LiteLLM proxy configuration. Purpose:

- One endpoint and one key per developer/project for every API-billed model.
- Translate between API formats (Anthropic, OpenAI) so any client can reach any model.
- Central place for spend limits, rate limits, logging, and switching providers.

It does **not** carry subscription traffic (C17). If the on-prem service is the only
API endpoint for now, skip the gateway and point `claude-onprem` straight at it.

## 7. Security model

### 7.1 Threats that matter most here

1. **Prompt injection with internet access.** An agent reads a malicious README, issue,
   web page or package and is instructed to exfiltrate secrets or push bad code.
   Outbound internet (D4) means exfiltration is possible. Mitigation is to make sure
   there is little worth stealing inside the container.
2. **Destructive commands** on the host or shared servers.
3. **Credential leakage** into git history, logs, prompts, or a public repo.
4. **Supply-chain**: agents installing typo-squatted or malicious packages.
5. **Data leaving the organisation** to a cloud model it should not reach.

### 7.2 Controls

| Layer | Control |
|---|---|
| Host | Agents never run directly on Windows. Code and tools live in WSL2 + dev container. |
| Container | Non-root user, `--cap-drop=ALL`, `no-new-privileges`, pids and memory limits, only the project folder mounted, no Docker socket mounted, no host home directory mounted. |
| Credentials in container | Only: on-prem AI token (forwarded from the host environment, never committed), AI tool logins (persisted in per-project named volumes) and a git token scoped to that one repo (fine-grained GitHub PAT or Azure DevOps PAT limited to Code read/write on that project). No cloud admin, production, or database credentials. |
| Claude Code | `permissions.deny` for `sudo`, reading `.env` and `secrets/`; `ask` for `git push`, `docker`, package publish; `PreToolUse` hook that blocks `curl \| sh`, `sudo`, `rm -rf /` style and `git push --force`. |
| Git platform | Branch protection on `main`: PR required, CI must pass, no force push. Agents push branches, humans merge. |
| CI | Secret scan (gitleaks) on every PR. Same `./scripts/check.sh` as local. |
| Network (servers) | On-prem AI and gateway on internal IPs only, TLS, bearer tokens. Docker ports bound to specific IPs (C14). SSH key-only, restricted source subnet. |
| Supply chain | Lockfiles committed; agents ask before adding a new dependency (AGENTS.md rule). Dependabot (GitHub) or equivalent. |
| Optional egress control | If stronger exfiltration protection is wanted later: an egress allowlist proxy, or Anthropic's reference dev container firewall script, for sensitive projects only. |

### 7.3 Data classification (needs owner input)

Proposed tiers, recorded per project in `AGENTS.md`:

| Tier | Example | Allowed models |
|---|---|---|
| Public | Open-source, this repo | Any |
| Internal | Internal tools, no personal info | Business/enterprise-tier cloud plans with no training on data, plus on-prem |
| Confidential | Customer, employee, financial, or personal information (Privacy Act) | On-prem only, unless the organisation approves a specific cloud provider |

Consumer and business plans from the same vendor differ on data retention and training
use. Which plans are in use, and whether company policy permits them for company code,
must be confirmed (section 11).

## 8. GitHub vs Azure DevOps

Choose at project creation (`-Platform`). The template copies only the matching folder.

| Concern | GitHub | Azure DevOps |
|---|---|---|
| CI file | `.github/workflows/ci.yml` | `azure-pipelines.yml` |
| PR template | `.github/pull_request_template.md` | `.azuredevops/pull_request_template.md` |
| Code owners | `CODEOWNERS` | Branch policy "automatically included reviewers" (no CODEOWNERS file) |
| Branch protection | Rulesets / branch protection | Branch policies |
| CLI for creating repo | `gh repo create` | `az repos create` (Azure CLI + `azure-devops` extension) |
| Agent in CI | Anthropic's Claude Code GitHub Action is available | Run `claude -p` (headless) in a pipeline step if wanted |
| Auth from container | Fine-grained PAT, or `gh auth login` | PAT, or Git Credential Manager |

Suggested rule of thumb (to confirm): Azure DevOps for company projects that sit with
other company work items, boards and Entra ID access control; GitHub for personal,
open-source, or projects that benefit from GitHub-native AI tooling.

## 9. Per-project file structure

Generated by `bin/New-AgenticProject.ps1` from `templates/project/common` plus one of
`templates/project/github` or `templates/project/azure-devops`.

```
<project>/
  AGENTS.md                     Cross-tool instructions: purpose, commands, rules, data tier
  CLAUDE.md                     "@AGENTS.md" + Claude-only notes
  README.md                     For humans
  .claude/
    settings.json               Shared Claude Code permissions + hooks (committed)
    hooks/guard-bash.sh         Blocks dangerous shell commands (PreToolUse)
  .cursor/rules/00-project.mdc  Points Cursor at AGENTS.md
  .devcontainer/
    devcontainer.json           Hardened agent sandbox (Cursor + VS Code)
  docs/
    architecture.md             Living architecture overview
    decisions/0001-*.md         Architecture Decision Records
    plans/                      Plans written by any agent (created when first used)
  scripts/check.sh              THE verification command (lint + test). Fill in per stack.
  scripts/claude-onprem.sh      Starts Claude Code against the on-prem API (Confidential work)
  src/  tests/
  .editorconfig .gitattributes .gitignore .env.example
  # GitHub projects add:
  .github/workflows/ci.yml  .github/pull_request_template.md
  # Azure DevOps projects add:
  azure-pipelines.yml  .azuredevops/pull_request_template.md
```

Language-specific scaffolding (package.json, pyproject.toml, .csproj) is deliberately
not included: it depends on the stack, and the agent should create it on day one using
the stack's own generator.

## 10. Rollout phases

1. **Phase 1 (workstation):** WSL2, Docker Desktop, Cursor, Claude Code, Codex, Git
   Credential Manager, `gh`, `az` + `azure-devops` extension. Install the
   PowerShell module from `bin/`. Create the first project from the template.
2. **Phase 2 (on-prem):** Confirm on-prem API details; set up `claude-onprem`. Stand up
   the LiteLLM gateway if third-party API models are wanted.
3. **Phase 3 (hardening):** Egress allowlist for confidential projects, gVisor on the
   Ubuntu Docker host, central logging of gateway usage, CI agent reviews.

## 11. Open questions

1. Which plan tier for each subscription (Claude Pro/Max/Team/Enterprise, Cursor
   Pro/Business, ChatGPT Plus/Pro/Business/Enterprise)? Personal or company-paid? Does
   company policy allow company code in each?
2. On-prem AI service: which product/models, what auth (API key header, bearer, mTLS),
   does it support streaming and tool use, what context window, internal hostname and
   TLS certificate (internal CA?).
3. Which third-party AI services are expected first (e.g. Gemini, Mistral, Azure
   OpenAI, AWS Bedrock)?
4. Azure DevOps organisation and project names; is Entra ID used for sign-in? GitHub:
   personal account only, or a company organisation?
5. Will the dev containers run on the Windows workstation (Docker Desktop) or on an
   Ubuntu server via Remote-SSH? Docker Desktop requires a paid licence for
   organisations above its small-business threshold; check that.
6. Main languages/stacks, so `scripts/check.sh` and CI can get real defaults.
7. Who else will use this (team of one, or more developers)? Affects gateway keys,
   CODEOWNERS, and branch policies.
8. Data classification tiers (7.3): agree or amend, and who signs off.

## 12. Claims to re-verify against current docs

These areas change frequently; the reviewer should check them:

- Claude Code: settings schema, permission rule syntax, hook event names and exit-code
  semantics, `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` / model env vars, native
  sandbox support on WSL2, reference dev container.
- Cursor: rules format (`.mdc` frontmatter), `AGENTS.md` support, dev container support.
- OpenAI Codex: `AGENTS.md` behaviour, ChatGPT sign-in for CLI, config file location,
  ability to run as an MCP server.
- LiteLLM: current image names/tags, non-root image, Anthropic `/v1/messages`
  passthrough for Claude Code.
- Docker Desktop licensing terms.
- Vendor data-retention/training terms per plan.

## 13. Files in this repo

| Path | Purpose |
|---|---|
| `docs/HANDOFF.md` | This document |
| `templates/project/` | Project skeleton (common + per-platform) |
| `bin/New-AgenticProject.ps1` | Creates a project from the template, optional remote |
| `bin/AgenticOS.psm1` | PowerShell helpers, including `claude-onprem` |
| `templates/project/common/scripts/claude-onprem.sh` | Bash equivalent, used inside the dev container |
| `gateway/` | Phase 2 LiteLLM gateway (compose + config) |
