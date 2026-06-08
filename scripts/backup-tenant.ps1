# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Exports tenant objects (users / groups / roles) as one JSON payload for backup.
# Restore-friendly: each object carries stable match keys (UPN, mailNickname) — no passwords.
param(
    [Parameter(Mandatory = $true)]
    [string]$Categories
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

# Page through a Graph collection endpoint, following @odata.nextLink.
function Get-GraphAll {
    param([string]$Uri)
    $items = New-Object System.Collections.Generic.List[object]
    $next = $Uri
    while ($next) {
        # Hashtable output: indexer access avoids the "Argument types do not match" error from .value on large arrays.
        $resp = Invoke-MgGraphRequest -Method GET -Uri $next -OutputType HashTable -ErrorAction Stop
        $vals = $resp['value']
        if ($null -ne $vals) { foreach ($v in @($vals)) { $items.Add($v) } }
        $next = $resp['@odata.nextLink']
    }
    return $items
}

$wanted = @($Categories -split ',' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
$catData = @{}

try {
    $tenantDomain = ''
    try {
        $org = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/organization?`$select=verifiedDomains" -OutputType HashTable -ErrorAction Stop
        $orgFirst = @($org['value'])[0]
        if ($orgFirst) {
            foreach ($d in @($orgFirst.verifiedDomains)) {
                if ($d.isDefault -eq $true) { $tenantDomain = [string]$d.name; break }
            }
        }
    } catch {}

    if ($wanted -contains 'users') {
        Write-Host "Sichere Benutzer..."
        $u = Get-GraphAll "/v1.0/users?`$select=id,userPrincipalName,displayName,givenName,surname,department,jobTitle,accountEnabled,usageLocation,assignedLicenses,userType,onPremisesSyncEnabled&`$top=999"
        Write-Host "  $(@($u).Count) Benutzer gefunden, verarbeite..."
        $usersOut = New-Object System.Collections.Generic.List[object]
        $skippedUsers = 0
        foreach ($usr in $u) {
            $upn = [string]$usr.userPrincipalName
            $uType = [string]$usr.userType
            $synced = ($usr.onPremisesSyncEnabled -eq $true)
            # Skip objects that cannot be cleanly re-created: guests (#EXT#) and on-prem synced accounts.
            if ($uType -eq 'Guest' -or $upn -like '*#EXT#*' -or $synced) {
                $skippedUsers++
                continue
            }
            $skuIds = @()
            if ($null -ne $usr.assignedLicenses) {
                foreach ($lic in @($usr.assignedLicenses)) {
                    $sku = [string]$lic.skuId
                    if ($sku) { $skuIds += $sku }
                }
            }
            $usersOut.Add(@{
                userPrincipalName = $upn
                displayName       = [string]$usr.displayName
                givenName         = [string]$usr.givenName
                surname           = [string]$usr.surname
                department        = [string]$usr.department
                jobTitle          = [string]$usr.jobTitle
                accountEnabled    = [bool]$usr.accountEnabled
                usageLocation     = [string]$usr.usageLocation
                skuIds            = @($skuIds)
            })
        }
        $catData['users'] = $usersOut.ToArray()
        Write-Host "  Benutzer: $($usersOut.Count) (uebersprungen: $skippedUsers)"
    }

    if ($wanted -contains 'groups') {
        Write-Host "Sichere Gruppen..."
        $g = Get-GraphAll "/v1.0/groups?`$select=id,displayName,mailNickname,groupTypes,securityEnabled,mailEnabled,visibility,description&`$top=999"
        $totalGroups = @($g).Count
        Write-Host "  $totalGroups Gruppen gefunden, lade Mitglieder..."
        $groupsOut = New-Object System.Collections.Generic.List[object]
        $skippedGroups = 0
        $gi = 0
        foreach ($grp in $g) {
            $gi++
            $types = @()
            if ($null -ne $grp.groupTypes) { $types = @($grp.groupTypes) }
            # Dynamic-membership groups derive members from a rule; re-importing static members would be wrong.
            if ($types -contains 'DynamicMembership') {
                $skippedGroups++
                continue
            }
            Write-Host "  [$gi/$totalGroups] $([string]$grp.displayName)"
            $members = @(Get-GraphAll "/v1.0/groups/$($grp.id)/members?`$select=userPrincipalName&`$top=999" | ForEach-Object { [string]$_.userPrincipalName } | Where-Object { $_ })
            $owners = @(Get-GraphAll "/v1.0/groups/$($grp.id)/owners?`$select=userPrincipalName&`$top=999" | ForEach-Object { [string]$_.userPrincipalName } | Where-Object { $_ })
            $groupsOut.Add(@{
                displayName     = [string]$grp.displayName
                mailNickname    = [string]$grp.mailNickname
                groupTypes      = $types
                securityEnabled = [bool]$grp.securityEnabled
                mailEnabled     = [bool]$grp.mailEnabled
                visibility      = [string]$grp.visibility
                description     = [string]$grp.description
                members         = @($members)
                owners          = @($owners)
            })
        }
        $catData['groups'] = $groupsOut.ToArray()
        Write-Host "  Gruppen: $($groupsOut.Count) (uebersprungen: $skippedGroups)"
    }

    if ($wanted -contains 'roles') {
        Write-Host "Sichere Rollen..."
        $r = Get-GraphAll "/v1.0/directoryRoles?`$select=id,displayName,roleTemplateId"
        $totalRoles = @($r).Count
        Write-Host "  $totalRoles Rollen gefunden, lade Mitglieder..."
        $rolesOut = New-Object System.Collections.Generic.List[object]
        $ri = 0
        foreach ($role in $r) {
            $ri++
            Write-Host "  [$ri/$totalRoles] $([string]$role.displayName)"
            # directoryRoles/{id}/members rejects $top (custom page size unsupported) — omit it.
            $members = @(Get-GraphAll "/v1.0/directoryRoles/$($role.id)/members?`$select=userPrincipalName" | ForEach-Object { [string]$_.userPrincipalName } | Where-Object { $_ })
            $rolesOut.Add(@{
                displayName    = [string]$role.displayName
                roleTemplateId = [string]$role.roleTemplateId
                members        = @($members)
            })
        }
        $catData['roles'] = $rolesOut.ToArray()
        Write-Host "  Rollen: $($rolesOut.Count)"
    }

    $payload = @{
        schemaVersion = 1
        createdAt     = (Get-Date).ToUniversalTime().ToString("o")
        tenantDomain  = $tenantDomain
        categories    = $catData
    }
    $result = @{ status = "ok"; message = "Backup erstellt"; backup = $payload } | ConvertTo-Json -Depth 12 -Compress
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
