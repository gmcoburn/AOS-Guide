# PowerShell helpers for the Agentic OS. Import from your profile:
#   Import-Module ~/src/AOS-Guide/bin/AgenticOS.psm1
# Tokens are read from Microsoft.PowerShell.SecretManagement, never from files in a repo:
#   Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore
#   Register-SecretVault -Name aos -ModuleName Microsoft.PowerShell.SecretStore
#   Set-Secret -Vault aos -Name AOS_ONPREM_TOKEN

Set-Alias -Name New-AgenticProject -Value (Join-Path $PSScriptRoot 'New-AgenticProject.ps1')

# Loads on-prem settings into this session's environment so that dev containers
# opened afterwards (and claude-onprem) can see them. AOS_ONPREM_URL and
# AOS_ONPREM_MODEL are not secret; set them in your profile.
function Enable-AosOnPrem {
    if (-not $env:AOS_ONPREM_URL) { throw 'Set $env:AOS_ONPREM_URL in your profile first.' }
    $env:AOS_ONPREM_TOKEN = Get-Secret -Vault aos -Name AOS_ONPREM_TOKEN -AsPlainText
}

# Runs Claude Code on the host against the on-prem service. Prefer running agents in
# the dev container (scripts/claude-onprem.sh); this is for quick questions only.
function Start-ClaudeOnPrem {
    Enable-AosOnPrem
    $saved = @{}
    $vars = @{
        ANTHROPIC_BASE_URL                      = $env:AOS_ONPREM_URL
        ANTHROPIC_AUTH_TOKEN                    = $env:AOS_ONPREM_TOKEN
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'
    }
    if ($env:AOS_ONPREM_MODEL) { $vars.ANTHROPIC_MODEL = $env:AOS_ONPREM_MODEL }
    foreach ($k in $vars.Keys) {
        $saved[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, $vars[$k])
    }
    try { claude @args }
    finally {
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
}

Set-Alias -Name claude-onprem -Value Start-ClaudeOnPrem
Export-ModuleMember -Function Enable-AosOnPrem, Start-ClaudeOnPrem -Alias New-AgenticProject, claude-onprem
