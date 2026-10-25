# Agentic OS: Design Handoff for Review

| | |
|---|---|
| Owner | George Coburn |
| Date | 25/10/2026 |
| Status | Draft for independent review, revision 2 (owner answers added 25/10/2026). |
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
| Workstation | Windows 11 (editor only: Cursor / VS Code connect to servers over SSH) |
| Servers | Ubuntu servers on the internal network. **Dev containers and agents run here**, not on the workstation. |
| Organisation | Australian business (waste management). Australian date formats and units. Australian Privacy Act 1988 and the APPs apply to personal information. |
| AI use policy | Completely open: any AI tool may be used with company code. |
| Subscriptions | Claude **Team** plan (business terms; Claude Code through the Team seat). Cursor (tier: open). OpenAI ChatGPT (tier: open). |
| On-prem AI | Anthropic Messages API compatible service, **API key auth** (`x-api-key`, so clients use `ANTHROPIC_API_KEY`). Models, streaming and tool-use support: open. |
| Repo hosts | GitHub: personal account. Azure DevOps: company organisation on a legacy `*.visualstudio.com` URL, project "Systems Team". Exact names are kept in environment variables, not in this public repo. |

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
| C5 | Local DeepSeek-R1 / Qwen via Ollama on port 11434 | The actual on-prem service exposes an **Anthropic-compatible API** with API key auth, not Ollama. | Point Anthropic-speaking clients (Claude Code, gateway) at it with `ANTHROPIC_BASE_URL` + `ANTHROPIC_API_KEY`. |
| C6 | Models "must output an architecture map inside `<think>`" | `<think>` tags are a DeepSeek-R1 output quirk, not something to require of every model. | Plans are written to `docs/plans/<date>-<topic>.md` by whichever model plans. Any tool can then implement from the file. |
| C7 | Compose `image: ://microsoft.com` | Invalid image reference. | Dev container on `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`. |
| C8 | `OLLAMA_HOST=http://docker.internal` | The Docker Desktop hostname is `host.docker.internal`. | Not needed; see C5. |
| C9 | `networks: internal: true` | Contradicts the decision that agent containers have internet access (D4). Also blocks package installs. | Normal bridge network with outbound access; risk handled in section 7. |
| C10 | `cap_drop: ALL` then `cap_add: SETUID, SETGID, CHOWN` with `no-new-privileges` | Adding SETUID/SETGID back undoes much of the benefit and is only needed if the container runs as root and switches user. | Run as non-root `vscode` user, `--cap-drop=ALL`, `no-new-privileges`, PID and memory limits. Add individual capabilities back only if something proves it needs them. |
| C11 | Compose file as "the" agent sandbox | Neither Cursor nor Claude Code attaches to an arbitrary compose service by default. | Dev Containers (`.devcontainer/devcontainer.json`): supported by VS Code and Cursor, and Anthropic publishes a reference dev container for Claude Code. Compose is still fine for a project's own services (databases etc.). |
| C12 | gVisor | Practical on an Ubuntu Docker host, which is now where containers run. | Optional `runsc` runtime for agent containers (phase 3). |
| C13 | `ssh -N -L ...` then check `$LASTEXITCODE` for "tunnel active" | `ssh -N` blocks until the tunnel dies, so the success message never prints while the tunnel is up. | If a tunnel is needed, run it with `Start-Process` or use a mesh VPN (WireGuard/Tailscale). Better: on-prem service and gateway served over internal TLS with token auth, no tunnel. |
| C14 | `ufw deny 11434` protects the container port | **Docker bypasses ufw** for published ports (it writes its own iptables rules). A port published as `-p 11434:11434` is reachable regardless of ufw. | Publish container ports on `127.0.0.1` only, or filter in the `DOCKER-USER` iptables chain. Restrict SSH to the internal subnet, key-only. |
| C15 | `ufw --force reset` script | Running this remotely can drop the SSH session and lock you out. | Change firewall rules manually, from console access, with the SSH allow rule added before enabling. Not scripted in this repo. |
| C16 | "Guardrail" rules in `CLAUDE.md` (no sudo, no `curl \| bash`) | Instructions in a Markdown file are advisory. A model can ignore them, and prompt injection can override them. | Enforce with Claude Code `permissions.deny`, a `PreToolUse` hook, and the container boundary. Markdown rules remain as guidance. |
| C17 | Cloud models via the subscriptions can be routed anywhere | Subscriptions are tied to their first-party clients. A ChatGPT or Claude subscription does **not** come with API credits; a Cursor subscription only works inside Cursor. | Use each subscription through its native client (section 6.1). Only the on-prem service and pay-per-use API keys go through the gateway. |
| C18 | "Cost-free, infinite-token" local reasoning | On-prem compute has real costs and capacity limits, and model quality varies. | Route by task and data sensitivity, not by "free". |

## 5. Decision log

| ID | Decision | Status |
|---|---|---|
| D1 | Windows 11 workstation is the editor only; Ubuntu servers host code, containers and agents | Decided |
| D2 | Use hardened Docker containers and infrastructure where practical | Decided |
| D3 | GitHub (personal account) **or** Azure DevOps (company org, "Systems Team" project) per project, chosen at project creation | Decided |
| D4 | Agent containers have outbound internet access | Decided |
| D5 | Same file structure for every project, generated from `templates/project` | Decided |
| D6 | Claude via the Team plan; on-prem AI via API key | Decided |
| D7 | Company AI use policy is open: no per-tool restrictions on company code | Decided |
| D8 | `AGENTS.md` is the cross-tool instruction file; `CLAUDE.md` stays and points to it (`@AGENTS.md`), at both project and personal level | Decided |
| D9 | Agents run in a per-project Dev Container on an Ubuntu Docker host, opened from Cursor via Remote-SSH then "Reopen in Container" | Proposed |
| D10 | Agent containers join a dedicated Docker network (`aos-agents`) whose traffic to private address ranges is blocked except for allow-listed hosts (on-prem AI). Internet stays open (D4). | Proposed |
| D11 | Each subscription is used through its own client; no credential sharing | Proposed |
| D12 | A LiteLLM gateway fronts the on-prem service and any pay-per-use third-party APIs | Proposed (phase 2) |
| D13 | One verification command per project: `./scripts/check.sh`, used by humans, every agent, and CI | Proposed |
| D14 | Plans and decisions are files in the repo (`docs/plans/`, `docs/decisions/`), so any tool can pick up another tool's work | Proposed |
| D15 | Secrets never in repos or container images; injected at runtime from the environment | Proposed |
| D16 | Every AI-authored change lands via a pull request reviewed by a human | Proposed |
| D17 | Memory is files, not a hidden database: project memory in the repo, personal memory in one file on the server (section 6.4) | Decided |
| D18 | One personal rules file per user (`~/.config/aos/agents/AGENTS.md` on the server), mounted read-only into every dev container | Decided |
| D19 | Every project's `AGENTS.md` has a Learnings section that agents add to; plans carry a Progress checklist and "Next step" line so any tool can resume | Decided |

## 6. Target architecture

```
 Windows 11 workstation (editor only)
 +-------------------------------------------------------------+
 |  Cursor / VS Code  --Remote-SSH-->  "Reopen in Container"    |
 |  Git Credential Manager (credentials forwarded to container) |
 +-------------------------------------------------------------+
                 | SSH (key only)
                 v
 Ubuntu dev server (Docker Engine)
 +-------------------------------------------------------------+
 |  ~/src/<project>          working copies                     |
 |                                                              |
 |  Docker network "aos-agents"  (scripts in server/)           |
 |  +-------------------------------------------------------+  |
 |  | Dev Container per project and user                    |  |
 |  | non-root, cap-drop ALL, no-new-privileges, limits     |  |
 |  |                                                       |  |
 |  |  claude        -> Anthropic cloud (Team plan login)   |  |
 |  |  claude-onprem -> on-prem Anthropic API (API key)     |  |
 |  |  codex         -> OpenAI cloud (ChatGPT login)        |  |
 |  |  git           -> GitHub / Azure DevOps               |  |
 |  +-------------------------------------------------------+  |
 |  Egress: internet allowed; private ranges blocked except    |
 |  allow-listed hosts (DOCKER-USER iptables chain)            |
 +-------------------------------------------------------------+
                 | internal network, TLS, API key
                 v
 On-prem AI service (Anthropic Messages API)
 LiteLLM gateway (phase 2): on-prem + third-party APIs
```

Why the servers rather than the workstation: no Docker Desktop licence or WSL2 needed,
agents keep running when the laptop sleeps, gVisor becomes an option, and the on-prem
AI is on the same network.

### 6.1 Which tool does what

| Tool | Access via | Best used for | Notes |
|---|---|---|---|
| Claude Code | CLI in the dev container, signed in with the Team plan | Multi-file features, refactors, running tests, git work, long autonomous tasks | Reads `CLAUDE.md` (which imports `AGENTS.md`), `.claude/settings.json`, hooks |
| Claude Code on-prem | Same CLI via `scripts/claude-onprem.sh` (sets `ANTHROPIC_BASE_URL`, `ANTHROPIC_API_KEY`, disables non-essential traffic) | Work you prefer to keep inside the network; heavy use that would hit Team plan limits | Needs the on-prem service to support streaming and tool use well enough for Claude Code |
| Cursor | Windows app, Remote-SSH into the server, attached to the dev container | Interactive editing, inline completion, UI tweaks, quick questions | Reads `AGENTS.md` and `.cursor/rules/*.mdc`. Turn on Privacy Mode. |
| OpenAI Codex | CLI or IDE extension in the dev container, ChatGPT sign-in | Second opinion, independent review of a branch, parallel tasks | Reads `AGENTS.md` |
| Third-party / API models | LiteLLM gateway (phase 2) | Specialist models, comparisons, scripts that call models directly | Pay-per-use API keys held by the gateway, not by projects |

There is no automatic "router" deciding which model answers. You choose the tool for
the task. What makes the tools cooperate is shared state on disk: `AGENTS.md`, plans
in `docs/plans/`, decisions in `docs/decisions/`, git branches, and one check command.

### 6.2 Typical workflow

1. On the Ubuntu server: `New-AgenticProject -Name foo -Platform AzureDevOps` (or
   `GitHub`) creates the project in `~/src` and optionally the remote repo.
2. In Cursor on Windows: Remote-SSH to the server, open `~/src/foo`, "Reopen in Container".
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

It does **not** carry subscription traffic (C17). While the on-prem service is the only
API endpoint, skip the gateway and point `claude-onprem` straight at it.

### 6.4 Memory

The tools do not share chat history with each other, so memory that every tool can use
has to be files. There are three layers:

| Layer | Where | What it holds | Who reads it |
|---|---|---|---|
| Personal | `~/.config/aos/agents/AGENTS.md` on the server, mounted read-only at `~/.aos/` in every container | Your preferences and cross-project lessons | Claude Code via `~/.claude/CLAUDE.md` (which contains only `@~/.aos/AGENTS.md`), Codex via `~/.codex/AGENTS.md` (a symlink). Cursor: same text pasted into User Rules. |
| Project | The repo: `AGENTS.md` (rules + Learnings), `docs/plans/` (with Progress), `docs/decisions/`, `docs/architecture.md`, git history and PRs | How this project works, what we learned, what is in flight and why | Every tool, every session |
| Session | Each tool's own history, in per-user, per-project Docker volumes | Conversation history for `claude --continue` and `codex resume` | Only the tool that wrote it |

How it stays current:

- **Learnings loop:** when an agent finds something non-obvious, `AGENTS.md` tells it to
  add one line to the Learnings section in the same change. You approve it in the PR.
- **Resumable plans:** `docs/plans/_template.md` has a Progress checklist and a "Next
  step" line that agents must update as they go and before a session ends.
- **Personal lessons:** edit the personal file on the server; every container sees the
  change immediately (it is a read-only bind mount, so agents cannot change it).

Deliberately not used yet: an MCP memory server or vector database. Hidden,
agent-written memory is hard to review and can be poisoned by prompt injection; files in
git are visible, reviewed and reversible. Revisit if the files become too large.

Implementation notes: the dev container is built from `.devcontainer/Dockerfile`, which
creates `~/.claude` and `~/.codex` owned by the non-root user (otherwise the named
volumes mounted over them start root-owned and unwritable) and writes the two pointer
files. These are copied into a volume only when the volume is first created, so
containers created before this change need their volumes removed once.

## 7. Security model

### 7.1 Threats that matter most here

1. **Prompt injection with internet access.** An agent reads a malicious README, issue,
   web page or package and is instructed to exfiltrate secrets or push bad code.
   Outbound internet (D4) means exfiltration is possible. Mitigation is to make sure
   there is little worth stealing inside the container.
2. **Lateral movement into the internal network.** Because containers run on internal
   Ubuntu servers, a hijacked agent could probe or attack other internal systems. This
   is the biggest risk introduced by running containers on the servers, and the reason
   for D10.
3. **Destructive commands** on shared servers.
4. **Credential leakage** into git history, logs, prompts, or a public repo.
5. **Supply-chain**: agents installing typo-squatted or malicious packages.

### 7.2 Controls

| Layer | Control |
|---|---|
| Workstation | Editor only. No agents, no Docker on Windows. |
| Docker host | Docker Engine from Docker's apt repo. Membership of the `docker` group is equivalent to root on the server, so limit it to admins, or use rootless Docker per user. SSH key-only, restricted source subnet. Optional gVisor (`runsc`) runtime. See `server/README.md`. |
| Container | Non-root user, `--cap-drop=ALL`, `no-new-privileges`, pids and memory limits, only the project folder mounted, no Docker socket mounted, no host home directory mounted, on the `aos-agents` network. |
| Network egress | `server/aos-egress.sh`: containers on `aos-agents` may reach the internet and DNS, but traffic to 10/8, 172.16/12, 192.168/16, 169.254/16 and 100.64/10 is rejected except for allow-listed host:port pairs (the on-prem AI, the gateway). |
| Credentials in container | Only: on-prem AI API key (from the server user's environment, never committed), AI tool logins (per-user, per-project named volumes), and git credentials forwarded by the editor for the session. No cloud admin, production, or database credentials. |
| Claude Code | `permissions.deny` for `sudo`, reading `.env` and `secrets/`; `ask` for `git push`, `docker`, package publish; `PreToolUse` hook that blocks `curl \| sh`, `sudo`, `rm -rf /` style and `git push --force`. |
| Git platform | Branch protection on `main`: PR required, CI must pass, no force push. Agents push branches, humans merge. |
| CI | Secret scan (gitleaks) on every PR. Same `./scripts/check.sh` as local. |
| Network (servers) | On-prem AI and gateway on internal IPs only, TLS, API keys. Docker ports bound to specific IPs (C14). |
| Supply chain | Lockfiles committed; agents ask before adding a new dependency (AGENTS.md rule). Dependabot (GitHub) or equivalent. |

### 7.3 Data handling

The company AI use policy is open (D7) and Claude is on the Team plan (business terms,
no training on your data by default), so no per-tool restrictions are applied. Two
things still hold regardless of AI policy:

- The **Privacy Act 1988** applies to personal information about customers and staff.
  Use synthetic or masked data in prompts, fixtures and tests rather than real records.
- Check the data settings on the other tools: Cursor **Privacy Mode** on, and if the
  ChatGPT plan is a personal one, turn off "improve the model for everyone".

## 8. GitHub vs Azure DevOps

Choose at project creation (`-Platform`). The template copies only the matching folder.

| Concern | GitHub (personal) | Azure DevOps (company) |
|---|---|---|
| CI file | `.github/workflows/ci.yml` | `azure-pipelines.yml` |
| PR template | `.github/pull_request_template.md` | `.azuredevops/pull_request_template.md` |
| Code owners | `CODEOWNERS` | Branch policy "automatically included reviewers" (no CODEOWNERS file) |
| Branch protection | Rulesets / branch protection | Branch policies; PR builds via a Build Validation policy |
| CLI for creating repo | `gh repo create` | `az repos create` (Azure CLI + `azure-devops` extension) |
| Agent in CI | Anthropic's Claude Code GitHub Action is available | Run `claude -p` (headless) in a pipeline step if wanted |
| Auth | `gh auth login` / Git Credential Manager | Git Credential Manager (Entra ID) or PAT |

Rule of thumb: **Azure DevOps for company work** (it sits with the Systems Team's boards
and company access control, and the company owns the code). **GitHub for personal
projects**, experiments and anything public. Avoid putting company code in the personal
GitHub account.

The script reads Azure DevOps defaults from environment variables so this public repo
never contains them:

```powershell
$env:AOS_ADO_ORG_URL = 'https://<org>.visualstudio.com'
$env:AOS_ADO_PROJECT = 'Systems Team'
```

## 9. Per-project file structure

Generated by `bin/New-AgenticProject.ps1` from `templates/project/common` plus one of
`templates/project/github` or `templates/project/azure-devops`.

```
<project>/
  AGENTS.md                     Cross-tool instructions: purpose, commands, rules, Learnings
  CLAUDE.md                     "@AGENTS.md" + Claude-only notes
  README.md                     For humans
  .claude/
    settings.json               Shared Claude Code permissions + hooks (committed)
    hooks/guard-bash.sh         Blocks dangerous shell commands (PreToolUse)
  .cursor/rules/00-project.mdc  Points Cursor at AGENTS.md
  .devcontainer/
    devcontainer.json           Hardened agent sandbox (Cursor + VS Code)
    Dockerfile                  Base image + tool homes + personal rules wiring
  docs/
    architecture.md             Living architecture overview
    decisions/0001-*.md         Architecture Decision Records
    plans/_template.md          Plan format with Progress checklist and Next step
  scripts/check.sh              THE verification command (lint + test). Fill in per stack.
  scripts/claude-onprem.sh      Starts Claude Code against the on-prem API
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

1. **Phase 1 (server + workstation):** On one Ubuntu server: Docker Engine, PowerShell 7,
   `gh`, `az` + `azure-devops` extension, `server/aos-egress.sh` and its systemd unit,
   SSH key-only. On Windows: Cursor with Remote-SSH and Dev Containers, Git Credential
   Manager. Create the first project and confirm Claude Code (Team login) and Codex work
   in the container.
2. **Phase 2 (on-prem + third parties):** Confirm on-prem API details, add it to the
   egress allow list, test `claude-onprem`. Stand up the LiteLLM gateway when the first
   third-party API is wanted.
3. **Phase 3 (hardening):** gVisor runtime for agent containers, central logging of
   gateway usage, CI agent reviews, Azure DevOps branch policies as a standard.

## 11. Open questions

1. Azure DevOps: the URL `<org>.visualstudio.com` names one organisation, but a
   different organisation name was given. Which is the real organisation (or is one a
   display name)? The script takes the full URL, so this only affects documentation.
2. On-prem AI service: which product/models, does it support streaming and tool use,
   context window, and does its TLS certificate come from an internal CA (containers
   will need that CA installed)?
3. Cursor and ChatGPT plan tiers.
4. Which third-party AI services are expected first (e.g. Gemini, Mistral, Azure
   OpenAI, AWS Bedrock)?
5. Will other Systems Team members use the same Ubuntu server? Decides rootless Docker
   vs a shared daemon, and gateway keys.
6. Which Ubuntu release on the dev server; is Docker already installed, and how?
7. Main languages/stacks, so `scripts/check.sh` and CI can get real defaults.
8. Does Azure DevOps use self-hosted agents or Microsoft-hosted (`ubuntu-latest`)?
   The pipeline template assumes Microsoft-hosted with Docker available.

## 12. Claims to re-verify against current docs

These areas change frequently; the reviewer should check them:

- Claude Code: settings schema, permission rule syntax, hook event names and exit-code
  semantics, `ANTHROPIC_BASE_URL` / `ANTHROPIC_API_KEY` / model env vars (and how an
  API key interacts with an existing Team plan login), which Team seats include
  Claude Code, the devcontainer feature, reference dev container.
- Cursor: rules format (`.mdc` frontmatter), `AGENTS.md` support, Dev Containers over
  Remote-SSH, Privacy Mode.
- Docker: `DOCKER-USER` chain behaviour on Ubuntu 24.04 (iptables-nft), rootless Docker
  with Dev Containers, embedded DNS behaviour on user-defined networks.
- OpenAI Codex: `AGENTS.md` behaviour, ChatGPT sign-in for CLI, config file location,
  ability to run as an MCP server.
- LiteLLM: current image names/tags, non-root image, Anthropic `/v1/messages`
  passthrough for Claude Code.
- Vendor data-retention/training terms per plan.

## 13. Files in this repo

| Path | Purpose |
|---|---|
| `docs/HANDOFF.md` | This document |
| `templates/project/` | Project skeleton (common + per-platform) |
| `templates/personal/AGENTS.md` | Starting point for each user's personal rules file |
| `docs/GETTING-STARTED.md` | Plain-English setup and workflow guide |
| `bin/New-AgenticProject.ps1` | Creates a project from the template, optional remote |
| `bin/AgenticOS.psm1` | PowerShell helpers (`New-AgenticProject`, `claude-onprem`) |
| `templates/project/common/scripts/claude-onprem.sh` | Bash equivalent, used inside the dev container |
| `gateway/` | Phase 2 LiteLLM gateway (compose + config) |
| `server/` | Ubuntu Docker host notes, agent egress firewall script and systemd unit |

## 14. Comparison with published "agentic OS" patterns (25/10/2026)

The owner asked for a check against two articles: Pancake's "What is an agentic
operating system" and MindStudio's "Agentic OS architecture: Claude Code business
brain". **Neither page could be opened from the build environment** (blocked by its
network policy), so this comparison uses search-engine summaries of them and of related
MindStudio posts. The reviewer should read the originals and correct this section.

What the summaries say:

- **Pancake** is a product: role-based AI agents (growth, engineering, operations) run
  inside Slack as an "AI co-founder", with human approval required for irreversible or
  costly actions. The general idea of an agentic OS: infrastructure that coordinates
  several agents, gives them tools, keeps memory, enforces guardrails and routes tasks
  to specialists.
- **MindStudio** describes a framework for Claude Code: a persistent "business brain"
  (usually `CLAUDE.md`) loaded every session, a skills layer, an orchestration layer, a
  self-maintenance loop, scheduled execution, and session records kept between runs.

| Pattern | This design | Verdict |
|---|---|---|
| Persistent context ("business brain") | Personal and project `AGENTS.md`, reached from `CLAUDE.md` | On track. The articles centre on `CLAUDE.md`; keeping `CLAUDE.md` as the entry point that points to `AGENTS.md` gets the same effect for Claude and also covers Cursor and Codex. |
| Memory and self-maintenance | Learnings section, resumable plans, decision records, session history volumes | On track (added in this revision). |
| Guardrails and human approval for irreversible actions | Permission rules, guard hook, container, egress firewall, PRs with branch protection | On track, and stronger than described in either article. |
| Specialist routing | Human chooses the tool (section 6.1) | Deliberate difference. Automatic routing adds cost and failure modes for one developer. |
| Skills layer | Not yet | Gap. Add `.claude/skills/` for repeated procedures (new plan, release, handover) once real repeats appear. |
| Orchestration / sub-agents | Not yet | Gap. Claude Code sub-agents in `.claude/agents/` (for example a reviewer and a planner) are the low-cost next step. |
| Scheduled execution | Not yet | Gap, phase 3. A cron job on the server running `claude -p` in a project container (for example nightly dependency checks), with output as a PR, never a direct push. |
| Shared business context across projects | Personal file only | Gap. A small "Systems Team context" repo (systems, glossary, conventions) mounted read-only like the personal file would give every project the same company background. |

Overall: the foundation (context, memory, guardrails, repo structure) matches the
published patterns. The gaps are additions on top that the layout already has room for,
not changes to it.

