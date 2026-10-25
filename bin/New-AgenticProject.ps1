#Requires -Version 7.3
<#
.SYNOPSIS
    Creates a new project from templates/project, for GitHub or Azure DevOps.

.EXAMPLE
    ./New-AgenticProject.ps1 -Name invoice-tool -Platform GitHub -Path ~/src -CreateRemote

.EXAMPLE
    ./New-AgenticProject.ps1 -Name route-planner -Platform AzureDevOps -Path ~/src -CreateRemote
    # Org URL and project default to $env:AOS_ADO_ORG_URL and $env:AOS_ADO_PROJECT.
    # Pass -AdoOrganizationUrl https://<org>.visualstudio.com -AdoProject 'Systems Team' to override.

.NOTES
    Run with pwsh on the Ubuntu dev server, where the dev containers run. Remote creation
    needs `gh` (GitHub) or `az` with the azure-devops extension (Azure DevOps), signed in.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$Name,
    [Parameter(Mandatory)][ValidateSet('GitHub', 'AzureDevOps')][string]$Platform,
    [string]$Path = (Get-Location).Path,
    [switch]$CreateRemote,
    [string]$GitHubOwner,
    [ValidateSet('private', 'internal', 'public')][string]$Visibility = 'private',
    # Full organisation URL; works for dev.azure.com/<org> and legacy <org>.visualstudio.com.
    [string]$AdoOrganizationUrl = $env:AOS_ADO_ORG_URL,
    [string]$AdoProject = $env:AOS_ADO_PROJECT
)

$ErrorActionPreference = 'Stop'
# Make failing git/gh/az commands stop the script instead of carrying on.
$PSNativeCommandUseErrorActionPreference = $true

$templateRoot = Join-Path $PSScriptRoot '..' 'templates' 'project'
$platformDir = @{ GitHub = 'github'; AzureDevOps = 'azure-devops' }[$Platform]
$target = Join-Path $Path $Name

if (Test-Path $target) { throw "Target already exists: $target" }
if ($CreateRemote -and $Platform -eq 'AzureDevOps' -and (-not $AdoOrganizationUrl -or -not $AdoProject)) {
    throw 'Azure DevOps remote needs -AdoOrganizationUrl and -AdoProject (or $env:AOS_ADO_ORG_URL and $env:AOS_ADO_PROJECT).'
}

if (-not $PSCmdlet.ShouldProcess($target, "Create $Platform project")) { return }

New-Item -ItemType Directory -Path $target | Out-Null
# -Force includes dot-files (.claude, .github, .gitignore) which a plain wildcard skips.
foreach ($src in @((Join-Path $templateRoot 'common'), (Join-Path $templateRoot $platformDir))) {
    Get-ChildItem -Path $src -Force | Copy-Item -Destination $target -Recurse -Force
}

$tokens = @{
    '{{PROJECT_NAME}}' = $Name
    '{{PROJECT_SLUG}}' = $Name.ToLowerInvariant() -replace '[^a-z0-9-]', '-'
    '{{PLATFORM}}'     = $Platform
    '{{DATE}}'         = (Get-Date -Format 'dd/MM/yyyy')
}
Get-ChildItem -Path $target -Recurse -File -Force | ForEach-Object {
    $text = Get-Content -Raw -Path $_.FullName
    if ($null -eq $text -or $text -notmatch '\{\{[A-Z_]+\}\}') { return }
    foreach ($key in $tokens.Keys) { $text = $text.Replace($key, $tokens[$key]) }
    Set-Content -Path $_.FullName -Value $text -NoNewline
}

# Personal rules shared by every project: created once from the template, then yours to edit.
$personalRules = Join-Path $HOME '.config' 'aos' 'agents' 'AGENTS.md'
if (-not (Test-Path $personalRules)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $personalRules) | Out-Null
    Copy-Item -Path (Join-Path $PSScriptRoot '..' 'templates' 'personal' 'AGENTS.md') -Destination $personalRules
    Write-Host "Created your personal rules file: $personalRules (edit it to suit you)."
}

Push-Location $target
try {
    if ($IsLinux -or $IsMacOS) {
        chmod +x scripts/check.sh scripts/claude-onprem.sh .claude/hooks/guard-bash.sh
    }
    git init -b main | Out-Null
    git add -A
    # Executable bit for Windows-created repos, where chmod is unavailable.
    git update-index --chmod=+x scripts/check.sh scripts/claude-onprem.sh .claude/hooks/guard-bash.sh
    git commit -m "Initial project structure from AOS-Guide template" | Out-Null

    if ($CreateRemote) {
        switch ($Platform) {
            'GitHub' {
                $repo = if ($GitHubOwner) { "$GitHubOwner/$Name" } else { $Name }
                gh repo create $repo "--$Visibility" --source . --remote origin --push
            }
            'AzureDevOps' {
                $remoteUrl = az repos create --name $Name --org $AdoOrganizationUrl --project $AdoProject --query remoteUrl -o tsv
                if (-not $remoteUrl) { throw 'az repos create returned no remote URL.' }
                git remote add origin $remoteUrl
                git push -u origin main
            }
        }
        Write-Host 'Next: protect main (PR required, CI must pass, no force push).'
    }
}
finally {
    Pop-Location
}

Write-Host "Created $target ($Platform). In Cursor: Remote-SSH to this server, open the folder, 'Reopen in Container'."
