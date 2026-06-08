# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Creates a security or Microsoft 365 (unified) group; optionally assigns owners by UPN
param(
    [Parameter(Mandatory = $true)]
    [string]$DisplayName,
    [string]$Description,
    [ValidateSet('security', 'unified')]
    [string]$Type = 'security',
    [string]$MailNickname,
    [ValidateSet('Private', 'Public')]
    [string]$Visibility = 'Private',
    [string]$OwnerUpns
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$__mg365ScriptsRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__mg365ScriptsRoot 'Mg365-GraphModules.ps1')

Ensure-Module "Microsoft.Graph.Groups"
Ensure-Module "Microsoft.Graph.Users"

$__ms365ConnRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__ms365ConnRoot 'Connect-Mg365App.ps1')
Write-Host "Verbinde mit Microsoft Graph..."
try {
    Connect-Mg365App -ErrorAction Stop
} catch {
    $result = @{ status = "error"; message = "Verbindung fehlgeschlagen: $($_.Exception.Message)" } | ConvertTo-Json -Compress
    Write-Output "###JSON_START###"
    Write-Output $result
    Write-Output "###JSON_END###"
    exit 1
}

# Derive a mailNickname from the display name when none was supplied (required for unified groups).
function Get-MailNickname {
    param([string]$Name, [string]$Provided)
    if (-not [string]::IsNullOrWhiteSpace($Provided)) { return ($Provided -replace '[^A-Za-z0-9]', '') }
    $n = ($Name -replace '[^A-Za-z0-9]', '')
    if ([string]::IsNullOrWhiteSpace($n)) { $n = "group$([DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))" }
    return $n.ToLowerInvariant()
}

# Resolve owner UPNs to directory object ids; collect ones that cannot be resolved.
function Resolve-OwnerIds {
    param([string]$Upns)
    $resolved = New-Object System.Collections.Generic.List[string]
    $missing = New-Object System.Collections.Generic.List[string]
    $list = @($Upns -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    foreach ($upn in $list) {
        try {
            $u = Get-MgUser -UserId $upn -Property Id -ErrorAction Stop
            if ($u -and $u.Id) { $resolved.Add($u.Id) } else { $missing.Add($upn) }
        } catch {
            $missing.Add($upn)
        }
    }
    return [pscustomobject]@{ Resolved = @($resolved); Missing = @($missing) }
}

$body = @{
    displayName     = $DisplayName
    mailEnabled     = $false
    securityEnabled = $true
    mailNickname    = (Get-MailNickname -Name $DisplayName -Provided $MailNickname)
}
if (-not [string]::IsNullOrWhiteSpace($Description)) { $body['description'] = $Description }

if ($Type -eq 'unified') {
    $body['groupTypes'] = @('Unified')
    $body['mailEnabled'] = $true
    $body['securityEnabled'] = $false
    $body['visibility'] = $Visibility
} else {
    $body['groupTypes'] = @()
}

if (-not [string]::IsNullOrWhiteSpace($OwnerUpns)) {
    $owners = Resolve-OwnerIds -Upns $OwnerUpns
    # Abort before creating: an owner that cannot be resolved is a hard error.
    if ($owners.Missing.Count -gt 0) {
        $result = @{
            status       = "error"
            message      = "Owner nicht gefunden: $($owners.Missing -join ', '). Gruppe wurde nicht angelegt."
            ownerMissing = @($owners.Missing)
        } | ConvertTo-Json -Depth 6 -Compress
        Write-Output "###JSON_START###"
        Write-Output $result
        Write-Output "###JSON_END###"
        exit 1
    }
    if ($owners.Resolved.Count -gt 0) {
        $body['owners@odata.bind'] = @($owners.Resolved | ForEach-Object { "https://graph.microsoft.com/v1.0/directoryObjects/$_" })
    }
}

try {
    $created = Invoke-MgGraphRequest -Method POST -Uri "/v1.0/groups" -Body $body -ErrorAction Stop
    $result = @{
        status      = "ok"
        message     = "Gruppe erstellt"
        groupId     = $created.id
        displayName = $created.displayName
    } | ConvertTo-Json -Depth 6 -Compress
    Write-Output "###JSON_START###"
    Write-Output $result
    Write-Output "###JSON_END###"
    exit 0
} catch {
    $raw = "$($_.Exception.Message)"
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $raw += " $($_.ErrorDetails.Message)" }
    $result = @{ status = "error"; message = "Fehler: $raw" } | ConvertTo-Json -Compress
    Write-Output "###JSON_START###"
    Write-Output $result
    Write-Output "###JSON_END###"
    exit 1
}
