# Getting Started: The Simple Version

This guide explains the whole setup in plain words, then walks you through building it
and using it every day. For the technical detail and reasoning, see
[HANDOFF.md](HANDOFF.md).

---

## Part 1: The big picture (the "like I'm 5" bit)

Imagine you are building things with a team of very fast, very clever helpers.

| Real thing | Think of it as |
|---|---|
| **Your Windows PC** | Your **window**. You look through it and talk to the helpers. Nothing gets built here. |
| **The Ubuntu server** | The **workshop**. All the building happens here. |
| **A dev container** | A **playpen** inside the workshop, one per project. Helpers can make a mess in their playpen, but they can't climb out and break the rest of the workshop. |
| **Claude Code, Codex, Cursor** | The **helpers**. Each one is good at different jobs. |
| **The on-prem AI** | A helper who **lives in our building**, so nothing leaves the building. |
| **`AGENTS.md`** | The **rules sheet on the fridge**. Every helper reads it before starting. |
| **`./scripts/check.sh`** | The **"is it working?" button**. Everyone presses the same button. |
| **Git** | **Save points** in a video game. You can always go back. |
| **GitHub / Azure DevOps** | The **safe** where the finished work is kept. Azure DevOps for work projects, GitHub for personal ones. |
| **A pull request (PR)** | **Showing your work to the teacher** before it goes in the safe. You are the teacher. |

So the story is:

> You sit at your **window** (PC). You look into the **workshop** (server). Each project
> has its own **playpen** (container). The **helpers** (AI tools) work inside the playpen,
> following the **rules on the fridge** (AGENTS.md). When they are done, they press the
> **"is it working?" button** (check.sh). You look at what they made, and if it is good,
> it goes in the **safe** (Azure DevOps or GitHub).

---

## Part 2: Building it (one time only)

You do this once. Allow an afternoon. Ask the server admin for help with the server
steps if you don't have `sudo` there.

### 2.1 On the Ubuntu server (the workshop)

Connect to the server from PowerShell on your PC:

```powershell
ssh <your-username>@<server-name>
```

Then, on the server:

**Step 1. Install Docker** (this is what makes the playpens).
Follow the official guide: https://docs.docker.com/engine/install/ubuntu/
Then let yourself use it, and log out and back in:

```bash
sudo usermod -aG docker $USER
exit
```

**Step 2. Install the other tools.**

```bash
sudo snap install powershell --classic        # PowerShell, for the project-maker script
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash   # Azure CLI (Microsoft's official installer)
az extension add --name azure-devops
```

For the GitHub CLI (`gh`), follow https://github.com/cli/cli/blob/trunk/docs/install_linux.md

**Step 3. Get this guide's files onto the server.**

```bash
git clone -b claude/heterogeneous-agentic-os-rdcsbq https://github.com/gmcoburn/AOS-Guide.git ~/AOS-Guide
mkdir -p ~/src
```

(Once this is merged into `main`, you can drop the `-b ...` part.)

**Step 4. Build the playpen fence** (stops helpers wandering into the company network).
Follow [server/README.md](../server/README.md), section 3. In short:

```bash
cd ~/AOS-Guide/server
sudo cp aos-egress.default.example /etc/default/aos-egress
sudo nano /etc/default/aos-egress      # put the on-prem AI server's IP:port in the allow list
sudo cp aos-egress.sh /usr/local/sbin/
sudo cp aos-egress.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now aos-egress
```

**Step 5. Tell the server your settings.** Open `~/.profile` (`nano ~/.profile`) and add
at the bottom (fill in the real values):

```bash
export AOS_ONPREM_URL=https://<onprem-ai-address>
export AOS_ADO_ORG_URL=https://<org>.visualstudio.com
export AOS_ADO_PROJECT='Systems Team'
[ -r ~/.config/aos/onprem.env ] && . ~/.config/aos/onprem.env
```

Put the on-prem API key in its own private file:

```bash
mkdir -p ~/.config/aos
echo 'export AOS_ONPREM_API_KEY=<your-key>' > ~/.config/aos/onprem.env
chmod 600 ~/.config/aos/onprem.env
```

**Step 6. Log in to the safes.**

```bash
gh auth login                    # GitHub: choose HTTPS, follow the prompts
gh auth setup-git                # lets git use that GitHub login when pushing
az login --use-device-code       # Azure DevOps: it gives you a code to type into a browser
```

Git also needs a key for the Azure DevOps safe when pushing. Install **Git Credential
Manager** on the server using its Linux guide
(https://github.com/git-ecosystem/git-credential-manager/blob/release/docs/install.md),
then:

```bash
git-credential-manager configure
git config --global credential.credentialStore cache
git config --global credential.azreposCredentialType oauth
```

The first push to Azure DevOps will show a code to type into a browser, like `az login`.

**Step 7. Make the project-maker load automatically.**

```bash
pwsh -c 'New-Item -Force -ItemType Directory (Split-Path $PROFILE); Add-Content $PROFILE "Import-Module ~/AOS-Guide/bin/AgenticOS.psm1"'
```

### 2.2 On your Windows PC (the window)

**Step 1. Install:**
- **Cursor**: https://cursor.com
- **Git for Windows**: https://git-scm.com (this includes Git Credential Manager, which
  remembers your passwords for GitHub and Azure DevOps)

**Step 2. Make an SSH key** (a key so the workshop door opens without a password).
In PowerShell:

```powershell
ssh-keygen -t ed25519
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh <your-username>@<server-name> "cat >> ~/.ssh/authorized_keys"
```

**Step 3. Give the server a nickname.** Open (or create) `C:\Users\<you>\.ssh\config`
and add:

```
Host devbox
    HostName <server-name-or-ip>
    User <your-username>
```

Now `ssh devbox` just works.

**Step 4. Set up Cursor.**
- Open Cursor. Go to Extensions and install **Remote - SSH** and **Dev Containers**.
- Settings > Privacy: turn on **Privacy Mode**.

That's the building done.

---

## Part 3: Starting a new project (a few minutes each time)

**Step 1. Make the project on the server.** In PowerShell on your PC:

```powershell
ssh devbox
pwsh
```

Then, for a **work** project:

```powershell
New-AgenticProject -Name my-project -Platform AzureDevOps -Path ~/src -CreateRemote
```

Or for a **personal** project:

```powershell
New-AgenticProject -Name my-project -Platform GitHub -Path ~/src -CreateRemote
```

This builds the folder with all the standard files and makes the repo in the safe.

**Step 2. Open it in Cursor.**
1. In Cursor press `Ctrl+Shift+P`, type **Remote-SSH: Connect to Host**, pick `devbox`.
2. **File > Open Folder** > `~/src/my-project`.
3. Press `Ctrl+Shift+P`, type **Dev Containers: Reopen in Container**.
   The first time takes a few minutes while it builds the playpen.

**Step 3. Wake up the helpers** (first time per project only). Open the terminal in
Cursor (`` Ctrl+` ``):

```bash
claude      # log in with your Claude Team account when asked
codex       # sign in with your ChatGPT account when asked
```

Both show a link to open in your browser. If the Codex sign-in page can't get back to
the container, check Cursor's **Ports** tab is forwarding the port it uses, or follow
Codex's instructions for signing in on a remote machine.

Inside the playpen, Cursor passes your Windows Git sign-in through for pushing, so
you normally don't need to log in to GitHub or Azure DevOps again.

**Step 4. Let Claude write the rules sheet.** In Claude, say something like:

> This project is a <what it is> written in <language>. Fill in AGENTS.md, set up the
> project for that language, and make ./scripts/check.sh run the linter and tests.

Read what it wrote in `AGENTS.md`. Fix anything wrong. This is the most important file:
every helper follows it.

**Step 5. Lock the safe door.** So nothing goes into `main` without you checking it:
- **Azure DevOps:** Repos > Branches > `main` > ... > Branch policies. Turn on
  "Require a minimum number of reviewers" and add a **Build validation** using
  `azure-pipelines.yml`.
- **GitHub:** Settings > Branches (or Rules) > add a rule for `main`: require a pull
  request and passing checks, block force pushes.

---

## Part 4: The everyday workflow

Every piece of work follows the same seven steps. Think: **Plan, Build, Check, Look,
Ask a friend, Save, Share.**

```
  1 Branch --> 2 Plan --> 3 Build --> 4 Look --> 5 Second opinion --> 6 Save --> 7 Share
                  ^                       |
                  +------ not right? -----+
```

**1. Start a fresh branch** (a new save slot, so `main` stays safe).

```bash
git switch main && git pull
git switch -c feature/short-name
```

**2. Plan first.** Ask Claude (or Codex, or the on-prem AI):

> Write a plan for <the thing you want> in docs/plans/. Don't write any code yet.

Read the plan. Change anything you don't like. Small jobs can skip this step.

**3. Build.** Tell Claude:

> Do the plan in docs/plans/<file>. Run ./scripts/check.sh until it passes.

Claude will ask permission before risky things (like pushing). Say yes or no.

**4. Look at what it did.** In Cursor, open the **Source Control** panel (left side) to
see every changed file. Use Cursor's chat or inline edits (`Ctrl+K`) for small tweaks.
If it's wrong, go back to step 2 or 3 and say what's wrong.

**5. Ask a different helper to check.** In the terminal:

```bash
codex
```

> Review the changes on this branch compared to main. Look for bugs and anything that
> doesn't match AGENTS.md.

A helper from a different company spots different mistakes.

**6. Save.**

```bash
./scripts/check.sh
git add -A
git commit -m "Add short description of the change"
git push -u origin feature/short-name
```

(Or just ask Claude: "commit and push this".)

**7. Share and merge.** Open a pull request in Azure DevOps or GitHub. The template asks
which AI tools helped. CI presses the "is it working?" button again. You read it,
you approve it, you merge it. Done.

---

## Part 5: Which helper for which job?

| I want to... | Use |
|---|---|
| Build a feature, fix a bug, change lots of files, run tests | **Claude Code** (`claude`) |
| Make a small edit, autocomplete as I type, ask a quick question | **Cursor** (chat or `Ctrl+K`) |
| Get a second opinion or a code review | **Codex** (`codex`) |
| Keep everything inside the company, or I've hit my Claude limit | **On-prem AI** (`./scripts/claude-onprem.sh`) |
| Plan something big | Any of them. Ask for the plan in `docs/plans/` |

---

## Part 6: Golden rules

1. **Never let a helper work outside its playpen.** Always "Reopen in Container".
2. **Never put passwords or keys in the project.** They go in `.env` (which git ignores)
   or in your `~/.profile` on the server.
3. **Never use real customer or staff details** in prompts or tests. Make up fake ones.
4. **Always work on a branch.** Never straight on `main`.
5. **Always press the button** (`./scripts/check.sh`) before saying it's done.
6. **You are the teacher.** Read every pull request before merging. The helpers are
   clever but they do make mistakes, and they sound confident even when wrong.
7. **Keep `AGENTS.md` up to date.** If you find yourself telling a helper the same
   thing twice, add it to `AGENTS.md`.

---

## Part 7: When things go wrong

| Problem | Try this |
|---|---|
| "Reopen in Container" fails saying network `aos-agents` not found | The fence isn't built on this server. Do Part 2.1 step 4. |
| A helper can't reach the on-prem AI | Its IP:port isn't in `/etc/default/aos-egress`. Add it, then `sudo systemctl restart aos-egress`. |
| `claude-onprem.sh` says a setting is missing | Check `~/.profile` on the server (Part 2.1 step 5), then rebuild the container: `Ctrl+Shift+P` > **Dev Containers: Rebuild Container**. |
| A helper says it was "Blocked by guard-bash.sh" | It tried something dangerous (like `sudo` or force-push). If you really need it, run it yourself. |
| `New-AgenticProject` isn't found | Run `pwsh` first, or redo Part 2.1 step 7. |
| Pushing from inside the playpen asks for a password | On Windows, push once to that site from any folder so Git Credential Manager remembers you, then reconnect Cursor. |
| Pushing from the server (outside the playpen) asks for a password | GitHub: `gh auth login` then `gh auth setup-git`. Azure DevOps: set up Git Credential Manager (Part 2.1 step 6). |
| Everything is confusing | Ask Claude, inside the project: "Read AGENTS.md and docs/, then explain how to <thing>". |

---

## Cheat sheet

```text
NEW PROJECT        ssh devbox  ->  pwsh  ->  New-AgenticProject -Name x -Platform AzureDevOps -Path ~/src -CreateRemote
OPEN PROJECT       Cursor > Remote-SSH: devbox > Open ~/src/x > Reopen in Container
NEW WORK           git switch main && git pull && git switch -c feature/x
HELPERS            claude | codex | ./scripts/claude-onprem.sh
CHECK              ./scripts/check.sh
SAVE + SHARE       git add -A && git commit -m "..." && git push -u origin feature/x  ->  open a PR
```
