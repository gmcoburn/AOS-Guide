FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Tool homes are created here, owned by the non-root user, so the named volumes mounted
# over them start writable and pre-filled with these files.
# Personal rules live on the server in ~/.config/aos/agents/AGENTS.md, mounted read-only
# at ~/.aos. They are wired in the same way as project rules: CLAUDE.md points at
# AGENTS.md, and Codex reads AGENTS.md directly.
RUN install -d -o vscode -g vscode /home/vscode/.claude /home/vscode/.codex \
 && echo '@~/.aos/AGENTS.md' > /home/vscode/.claude/CLAUDE.md \
 && ln -s /home/vscode/.aos/AGENTS.md /home/vscode/.codex/AGENTS.md \
 && chown -h vscode:vscode /home/vscode/.claude/CLAUDE.md /home/vscode/.codex/AGENTS.md
