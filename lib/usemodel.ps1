# Implementation of `usemodel` for PowerShell. Not meant to be dot-sourced
# directly — dot-source ../config.ps1, which loads this. See that file for usage.

# Load a KEY=VALUE (.env style) file, setting each as an environment variable.
# Skips comments/blanks, strips surrounding double-quotes, and expands ${VAR}
# references from the environment (matching the fish/bash loaders).
function _litellm_loadenv {
    param([string]$EnvFile)
    if (-not (Test-Path -LiteralPath $EnvFile)) { return }
    foreach ($line in Get-Content -LiteralPath $EnvFile) {
        if ($line -match '^\s*(#|$)') { continue }
        $idx = $line.IndexOf('=')
        if ($idx -lt 0) { continue }
        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim().Trim('"')
        $val = [regex]::Replace($val, '\$\{(\w+)\}', {
            param($m)
            $v = [Environment]::GetEnvironmentVariable($m.Groups[1].Value)
            if ($null -eq $v) { '' } else { $v }
        })
        Set-Item -Path "Env:$key" -Value $val
    }
}

# Repo root is the parent of this lib/ directory.
$global:_litellmDir = Split-Path -Parent $PSScriptRoot

# Load API keys from the root .env (the same file docker-compose reads),
# so there's a single source of truth and no keys are hardcoded anywhere.
_litellm_loadenv (Join-Path $global:_litellmDir '.env')

# Collect every variable name declared by any bundle, so `usemodel` can reset
# exactly those — the bundle .env files are the single source of truth, with no
# hardcoded list to keep in sync.
$global:_litellmVars = @()
Get-ChildItem -Path (Join-Path $global:_litellmDir 'models') -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $bundle = Join-Path $_.FullName '.env'
    if (Test-Path -LiteralPath $bundle) {
        foreach ($line in Get-Content -LiteralPath $bundle) {
            if ($line -match '^\s*(#|$)') { continue }
            $idx = $line.IndexOf('=')
            if ($idx -lt 0) { continue }
            $key = $line.Substring(0, $idx).Trim()
            if ($global:_litellmVars -notcontains $key) { $global:_litellmVars += $key }
        }
    }
}

function usemodel {
    param([string]$Model)

    # Reset every var any bundle could set, so each switch starts from a clean
    # slate (this is also exactly what `default` does — back to native Anthropic).
    foreach ($v in $global:_litellmVars) {
        Remove-Item -Path "Env:$v" -ErrorAction SilentlyContinue
    }

    if ([string]::IsNullOrEmpty($Model) -or $Model -eq 'default') { return }

    $envfile = Join-Path $global:_litellmDir "models/$Model/.env"
    if (-not (Test-Path -LiteralPath $envfile)) {
        $avail = @('default')
        Get-ChildItem -Path (Join-Path $global:_litellmDir 'models') -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            if (Test-Path -LiteralPath (Join-Path $_.FullName '.env')) { $avail += $_.Name }
        }
        Write-Error "Unknown model: $Model. Available: $($avail -join ', ')"
        return
    }
    _litellm_loadenv $envfile

    # A bundle that references a secret (e.g. ANTHROPIC_AUTH_TOKEN=${DEEPSEEK_API_KEY})
    # ends up empty if that key isn't in .env — flag it instead of failing silently.
    if ([string]::IsNullOrEmpty($env:ANTHROPIC_AUTH_TOKEN)) {
        Write-Warning "Bundle '$Model' has an empty ANTHROPIC_AUTH_TOKEN — is its key set in .env (see .env.example)?"
    }
}
