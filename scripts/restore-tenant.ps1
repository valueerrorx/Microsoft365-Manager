# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Restores selected categories (users / groups / roles / intunePolicies) from a backup JSON.
# Conflict policy: existing objects (matched by UPN / mailNickname / roleTemplateId) are skipped, only missing ones are created.
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupPath,
    [Parameter(Mandatory = $true)]
    [string]$Categories,
    [string]$DefaultPassword
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
    Write-Output "###JSON_START###"; Write-Output $result; Write-Output "###JSON_END###"; exit 1
}

# Load + parse the backup file.
try {
    $json = Get-Content -LiteralPath $BackupPath -Raw -Encoding UTF8 -ErrorAction Stop
    $backup = $json | ConvertFrom-Json -ErrorAction Stop
} catch {
    $result = @{ status = "error"; message = "Backup-Datei ungueltig: $($_.Exception.Message)" } | ConvertTo-Json -Compress
    Write-Output "###JSON_START###"; Write-Output $result; Write-Output "###JSON_END###"; exit 1
}

$wanted = @($Categories -split ',' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
$cats = $backup.categories
$summary = @{}

# Page through a Graph collection endpoint, following @odata.nextLink.
function Get-GraphAll {
    param([string]$Uri)
    $items = New-Object System.Collections.Generic.List[object]
    $next = $Uri
    while ($next) {
        $resp = Invoke-MgGraphRequest -Method GET -Uri $next -OutputType HashTable -ErrorAction Stop
        $vals = $resp['value']
        if ($null -ne $vals) { foreach ($v in @($vals)) { $items.Add($v) } }
        $next = $resp['@odata.nextLink']
    }
    return $items
}

# Resolve a UPN to a directory object id; returns $null when not found.
function Resolve-UserId {
    param([string]$Upn)
    if ([string]::IsNullOrWhiteSpace($Upn)) { return $null }
    try {
        $u = Get-MgUser -UserId $Upn -Property Id -ErrorAction Stop
        if ($u -and $u.Id) { return $u.Id }
    } catch {}
    return $null
}

# Resolve group mailNickname to directory object id; returns $null when not found.
function Resolve-GroupIdByNick {
    param([string]$MailNickname)
    $nick = [string]$MailNickname
    if ([string]::IsNullOrWhiteSpace($nick)) { return $null }
    try {
        $f = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/groups?`$filter=mailNickname eq '$nick'&`$select=id" -OutputType HashTable -ErrorAction Stop
        $id = @($f['value'])[0].id
        if ($id) { return [string]$id }
    } catch {}
    return $null
}

# Convert backup JSON nodes to hashtables for Graph POST bodies.
function ConvertTo-HashtableDeep {
    param($InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $ht = @{}
        foreach ($k in @($InputObject.Keys)) { $ht[$k] = ConvertTo-HashtableDeep $InputObject[$k] }
        return $ht
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        return @($InputObject | ForEach-Object { ConvertTo-HashtableDeep $_ })
    }
    return $InputObject
}

# POST Intune policy assignments from portable backup targets.
function Set-IntunePolicyAssignments {
    param(
        [string]$AssignUri,
        [array]$Assignments,
        [System.Collections.Generic.List[string]]$Errors,
        [string]$PolicyLabel
    )
    $assignList = New-Object System.Collections.Generic.List[object]
    foreach ($a in @($Assignments)) {
        $target = $null
        $t = [string]$a.target
        if ($t -eq 'allDevices') {
            $target = @{ '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget' }
        } elseif ($t -eq 'allLicensedUsers') {
            $target = @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' }
        } elseif ($t -eq 'group') {
            $nick = [string]$a.mailNickname
            $gid = Resolve-GroupIdByNick $nick
            if (-not $gid) {
                $Errors.Add("Zuweisung $PolicyLabel : Gruppe '$nick' nicht gefunden")
                continue
            }
            $target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $gid }
        }
        if ($target) { $assignList.Add(@{ target = $target }) }
    }
    if ($assignList.Count -eq 0) { return }
    try {
        Invoke-MgGraphRequest -Method POST -Uri $AssignUri -Body @{ assignments = $assignList.ToArray() } -ErrorAction Stop | Out-Null
    } catch {
        $Errors.Add("Zuweisungen $PolicyLabel : $($_.Exception.Message)")
    }
}

try {
    if ($wanted -contains 'users' -and $cats.users) {
        $list = @($cats.users)
        $total = $list.Count
        Write-Host "Stelle Benutzer wieder her ($total)..."
        $created = 0; $skipped = 0; $failed = 0
        $errors = New-Object System.Collections.Generic.List[string]
        $i = 0
        foreach ($usr in $list) {
            $i++
            $upn = [string]$usr.userPrincipalName
            if (-not $upn) { continue }
            Write-Host "  [$i/$total] $upn"
            # Skip existing users (conflict policy: only create missing).
            $existing = $null
            try { $existing = Get-MgUser -UserId $upn -Property Id -ErrorAction Stop } catch {}
            if ($existing) { $skipped++; continue }
            try {
                $mailNick = ($upn -split '@')[0]
                $pwProfile = @{ password = $DefaultPassword; forceChangePasswordNextSignIn = $true }
                $body = @{
                    accountEnabled    = [bool]$usr.accountEnabled
                    displayName       = [string]$usr.displayName
                    userPrincipalName = $upn
                    mailNickname      = $mailNick
                    passwordProfile   = $pwProfile
                }
                if ($usr.givenName) { $body['givenName'] = [string]$usr.givenName }
                if ($usr.surname) { $body['surname'] = [string]$usr.surname }
                if ($usr.department) { $body['department'] = [string]$usr.department }
                if ($usr.jobTitle) { $body['jobTitle'] = [string]$usr.jobTitle }
                if ($usr.usageLocation) { $body['usageLocation'] = [string]$usr.usageLocation }
                $new = Invoke-MgGraphRequest -Method POST -Uri "/v1.0/users" -Body $body -ErrorAction Stop
                $created++
                # Re-apply licenses (skuIds only); needs usageLocation, which we set above.
                $skuIds = @($usr.skuIds | Where-Object { $_ })
                if ($skuIds.Count -gt 0 -and $new.id) {
                    $addLic = @($skuIds | ForEach-Object { @{ skuId = $_ } })
                    try {
                        Invoke-MgGraphRequest -Method POST -Uri "/v1.0/users/$($new.id)/assignLicense" -Body @{ addLicenses = $addLic; removeLicenses = @() } -ErrorAction Stop | Out-Null
                    } catch {
                        $errors.Add("Lizenz $upn : $($_.Exception.Message)")
                    }
                }
            } catch {
                $failed++
                $errors.Add("$upn : $($_.Exception.Message)")
            }
        }
        $summary['users'] = @{ created = $created; skipped = $skipped; failed = $failed; errors = $errors.ToArray() }
        Write-Host "  Benutzer: erstellt $created, uebersprungen $skipped, fehlgeschlagen $failed"
    }

    if ($wanted -contains 'groups' -and $cats.groups) {
        $list = @($cats.groups)
        $total = $list.Count
        Write-Host "Stelle Gruppen wieder her ($total)..."
        $created = 0; $skipped = 0; $failed = 0
        $errors = New-Object System.Collections.Generic.List[string]
        $i = 0
        foreach ($grp in $list) {
            $i++
            $name = [string]$grp.displayName
            $nick = [string]$grp.mailNickname
            Write-Host "  [$i/$total] $name"
            # Match existing by mailNickname; skip if present.
            $exists = $false
            if ($nick) {
                try {
                    $f = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/groups?`$filter=mailNickname eq '$nick'&`$select=id" -OutputType HashTable -ErrorAction Stop
                    if (@($f['value']).Count -gt 0) { $exists = $true }
                } catch {}
            }
            if ($exists) { $skipped++; continue }
            try {
                $types = @($grp.groupTypes)
                $isUnified = $types -contains 'Unified'
                if (-not $nick) { $nick = ($name -replace '[^A-Za-z0-9]', '').ToLowerInvariant() }
                $body = @{
                    displayName     = $name
                    mailNickname    = $nick
                    mailEnabled     = [bool]$grp.mailEnabled
                    securityEnabled = [bool]$grp.securityEnabled
                    groupTypes      = $types
                }
                if ($grp.description) { $body['description'] = [string]$grp.description }
                if ($isUnified -and $grp.visibility) { $body['visibility'] = [string]$grp.visibility }
                # Resolve owners/members up front; bind owners at creation (unified groups need >=1 owner).
                $ownerIds = @($grp.owners | ForEach-Object { Resolve-UserId $_ } | Where-Object { $_ })
                if ($ownerIds.Count -gt 0) {
                    $body['owners@odata.bind'] = @($ownerIds | ForEach-Object { "https://graph.microsoft.com/v1.0/directoryObjects/$_" })
                }
                $newGrp = Invoke-MgGraphRequest -Method POST -Uri "/v1.0/groups" -Body $body -ErrorAction Stop
                $created++
                foreach ($mUpn in @($grp.members)) {
                    $mid = Resolve-UserId $mUpn
                    if (-not $mid) { $errors.Add("Mitglied nicht gefunden ($name): $mUpn"); continue }
                    try {
                        Invoke-MgGraphRequest -Method POST -Uri "/v1.0/groups/$($newGrp.id)/members/`$ref" -Body @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$mid" } -ErrorAction Stop | Out-Null
                    } catch {
                        $raw = "$($_.Exception.Message)"
                        if ($raw -notlike '*already exist*') { $errors.Add("Mitglied $mUpn -> $name : $raw") }
                    }
                }
            } catch {
                $failed++
                $errors.Add("$name : $($_.Exception.Message)")
            }
        }
        $summary['groups'] = @{ created = $created; skipped = $skipped; failed = $failed; errors = $errors.ToArray() }
        Write-Host "  Gruppen: erstellt $created, uebersprungen $skipped, fehlgeschlagen $failed"
    }

    if ($wanted -contains 'roles' -and $cats.roles) {
        $list = @($cats.roles)
        $total = $list.Count
        Write-Host "Stelle Rollen wieder her ($total)..."
        $assigned = 0; $skipped = 0; $failed = 0
        $errors = New-Object System.Collections.Generic.List[string]
        $i = 0
        foreach ($role in $list) {
            $i++
            $tplId = [string]$role.roleTemplateId
            $rname = [string]$role.displayName
            Write-Host "  [$i/$total] $rname"
            $roleMembers = @($role.members | Where-Object { $_ })
            if (-not $tplId -or $roleMembers.Count -eq 0) { continue }
            # Ensure the directory role is activated, then look up its id.
            $roleId = $null
            try {
                $existing = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/directoryRoles?`$filter=roleTemplateId eq '$tplId'&`$select=id" -OutputType HashTable -ErrorAction Stop
                $roleId = @($existing['value'])[0].id
            } catch {}
            if (-not $roleId) {
                try {
                    $act = Invoke-MgGraphRequest -Method POST -Uri "/v1.0/directoryRoles" -Body @{ roleTemplateId = $tplId } -ErrorAction Stop
                    $roleId = $act.id
                } catch {
                    $failed++; $errors.Add("Rolle $rname aktivieren: $($_.Exception.Message)"); continue
                }
            }
            foreach ($mUpn in $roleMembers) {
                $mid = Resolve-UserId $mUpn
                if (-not $mid) { $errors.Add("Rollen-Mitglied nicht gefunden ($rname): $mUpn"); continue }
                try {
                    Invoke-MgGraphRequest -Method POST -Uri "/v1.0/directoryRoles/$roleId/members/`$ref" -Body @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$mid" } -ErrorAction Stop | Out-Null
                    $assigned++
                } catch {
                    $raw = "$($_.Exception.Message)"
                    if ($raw -like '*already exist*') { $skipped++ } else { $errors.Add("$mUpn -> $rname : $raw") }
                }
            }
        }
        $summary['roles'] = @{ assigned = $assigned; skipped = $skipped; failed = $failed; errors = $errors.ToArray() }
        Write-Host "  Rollen: zugewiesen $assigned, uebersprungen $skipped, fehlgeschlagen $failed"
    }

    if ($wanted -contains 'intunepolicies' -and $cats.intunePolicies) {
        $list = @($cats.intunePolicies)
        $total = $list.Count
        Write-Host "Stelle Intune-Richtlinien wieder her ($total)..."
        $created = 0; $skipped = 0; $failed = 0
        $errors = New-Object System.Collections.Generic.List[string]
        $existingCfg = @{}
        foreach ($p in @(Get-GraphAll '/beta/deviceManagement/configurationPolicies')) { $existingCfg[[string]$p.name] = $true }
        $existingCmp = @{}
        foreach ($p in @(Get-GraphAll '/beta/deviceManagement/deviceCompliancePolicies')) { $existingCmp[[string]$p.displayName] = $true }
        $i = 0
        foreach ($pol in $list) {
            $i++
            $kind = [string]$pol.kind
            $label = [string]$pol.displayName
            Write-Host "  [$i/$total] $label ($kind)"
            if (-not $label -or -not $kind) { continue }

            $exists = $false
            if ($kind -eq 'configurationPolicy' -and $existingCfg.ContainsKey($label)) { $exists = $true }
            elseif ($kind -eq 'compliancePolicy' -and $existingCmp.ContainsKey($label)) { $exists = $true }
            if ($exists) { $skipped++; continue }

            try {
                $body = ConvertTo-HashtableDeep $pol.payload
                if (-not $body) { throw 'Payload fehlt' }
                $policyId = $null
                if ($kind -eq 'configurationPolicy') {
                    $newPol = Invoke-MgGraphRequest -Method POST -Uri '/beta/deviceManagement/configurationPolicies' -Body $body -ErrorAction Stop
                    $policyId = [string]$newPol.id
                    foreach ($setting in @($pol.settings)) {
                        $sBody = ConvertTo-HashtableDeep $setting
                        if (-not $sBody) { continue }
                        try {
                            Invoke-MgGraphRequest -Method POST -Uri "/beta/deviceManagement/configurationPolicies/$policyId/settings" -Body $sBody -ErrorAction Stop | Out-Null
                        } catch {
                            $errors.Add("Setting $label : $($_.Exception.Message)")
                        }
                    }
                    Set-IntunePolicyAssignments -AssignUri "/beta/deviceManagement/configurationPolicies/$policyId/assign" -Assignments @($pol.assignments) -Errors $errors -PolicyLabel $label
                } elseif ($kind -eq 'compliancePolicy') {
                    $newPol = Invoke-MgGraphRequest -Method POST -Uri '/beta/deviceManagement/deviceCompliancePolicies' -Body $body -ErrorAction Stop
                    $policyId = [string]$newPol.id
                    Set-IntunePolicyAssignments -AssignUri "/beta/deviceManagement/deviceCompliancePolicies/$policyId/assign" -Assignments @($pol.assignments) -Errors $errors -PolicyLabel $label
                } else {
                    throw "Unbekannter kind: $kind"
                }
                $created++
            } catch {
                $failed++
                $errors.Add("$label : $($_.Exception.Message)")
            }
        }
        $summary['intunePolicies'] = @{ created = $created; skipped = $skipped; failed = $failed; errors = $errors.ToArray() }
        Write-Host "  Intune-Richtlinien: erstellt $created, uebersprungen $skipped, fehlgeschlagen $failed"
    }

    $result = @{ status = "ok"; message = "Wiederherstellung abgeschlossen"; summary = $summary } | ConvertTo-Json -Depth 12 -Compress
    Write-Output "###JSON_START###"; Write-Output $result; Write-Output "###JSON_END###"; exit 0
} catch {
    $raw = "$($_.Exception.Message)"
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $raw += " $($_.ErrorDetails.Message)" }
    $result = @{ status = "error"; message = "Fehler: $raw"; summary = $summary } | ConvertTo-Json -Depth 12 -Compress
    Write-Output "###JSON_START###"; Write-Output $result; Write-Output "###JSON_END###"; exit 1
}
