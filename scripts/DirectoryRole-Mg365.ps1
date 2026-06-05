# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Graph directory roles: list $filter on roleTemplateId is unreliable; members do not support $top.

function Get-ActivatedDirectoryRoleByTemplateId {
    param([string]$TemplateId)
    $uri = "/v1.0/directoryRoles(roleTemplateId='$TemplateId')"
    try {
        return Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
    } catch {
        $code = $null
        try { $code = [int]$_.Exception.Response.StatusCode } catch {}
        if ($code -eq 404) { return $null }
        throw
    }
}

function New-DirectoryRoleFromTemplate {
    param([string]$TemplateId)
    $body = @{ roleTemplateId = $TemplateId } | ConvertTo-Json -Compress
    return Invoke-MgGraphRequest -Method POST -Uri '/v1.0/directoryRoles' -Body $body -ContentType 'application/json' -ErrorAction Stop
}

function Get-OrActivateDirectoryRole {
    param([string]$TemplateId)
    $existing = Get-ActivatedDirectoryRoleByTemplateId -TemplateId $TemplateId
    if ($existing) { return $existing }
    Write-Host "Aktiviere Rolle (Template): $TemplateId"
    return New-DirectoryRoleFromTemplate -TemplateId $TemplateId
}

function Get-DirectoryRoleUserMembers {
    param([string]$TemplateId)
    $members = @()
    $uri = "/v1.0/directoryRoles(roleTemplateId='$TemplateId')/members"
    $resp = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
    foreach ($m in $resp.value) {
        $odataType = [string]$m.'@odata.type'
        if ($odataType -match 'user') {
            $members += @{
                id                = $m.id
                displayName       = $m.displayName
                mail              = $m.mail
                userPrincipalName = $m.userPrincipalName
                odataType         = $odataType
            }
        }
    }
    return $members
}
