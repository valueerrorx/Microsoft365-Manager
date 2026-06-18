# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Adds directory users to a group sequentially; treats "already member" as skipped
param(
    [Parameter(Mandatory = $true)]
    [string]$GroupId,
    [string]$UserIds,
    [string]$MemberIdsPath,
    [string]$GroupTypes,
    [string]$SecurityEnabled,
    [switch]$DeviceMembers
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$__mg365ScriptsRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__mg365ScriptsRoot 'Mg365-GraphModules.ps1')

Ensure-Module "Microsoft.Graph.Groups"

$__ms365ConnRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__ms365ConnRoot 'Connect-Mg365App.ps1')
Write-Host "Verbinde mit Microsoft Graph..."
try {
    Connect-Mg365App -ErrorAction Stop
} catch {
    $result = @{
        status  = "error"
        message = "Verbindung fehlgeschlagen: $($_.Exception.Message)"
        added   = 0
        skipped = 0
        failed  = 0
        errors  = @()
    } | ConvertTo-Json -Depth 4 -Compress
    Write-Output "###JSON_START###"
    Write-Output $result
    Write-Output "###JSON_END###"
    exit 1
}

function Test-IsAlreadyMemberError {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    $t = $Text.ToLowerInvariant()
    return $t.Contains('already exist') -or $t.Contains('added object references already exist') -or $t.Contains('one or more added object references already exist')
}

function Write-AddMembersJsonResult {
    param([hashtable]$Payload, [int]$ExitCode = 0)
    $json = $Payload | ConvertTo-Json -Depth 6 -Compress
    Write-Output "###JSON_START###"
    Write-Output $json
    Write-Output "###JSON_END###"
    exit $ExitCode
}

# Device directory objects are only accepted in security groups (not M365 Unified or dynamic).
function Test-GroupAcceptsDeviceMembers {
    param($GroupMeta)
    $types = @()
    if ($null -ne $GroupMeta.groupTypes) { $types = @($GroupMeta.groupTypes) }
    if ($types -contains 'DynamicMembership') {
        return @{ ok = $false; message = 'Dynamische Gruppen erlauben kein manuelles Hinzufuegen von Geraeten.' }
    }
    if ($types -contains 'Unified') {
        return @{ ok = $false; message = 'Microsoft-365-Gruppen unterstuetzen keine Geraete als Mitglieder.' }
    }
    if ($GroupMeta.securityEnabled -ne $true) {
        return @{ ok = $false; message = 'Nur Sicherheitsgruppen koennen Geraete als Mitglieder aufnehmen.' }
    }
    return @{ ok = $true; message = '' }
}

# Prefer group metadata from the app picker; fall back to Get-MgGroup when not supplied.
function Get-GroupMetaForDeviceCheck {
    param([string]$GroupTypesInline, [string]$SecurityEnabledInline, [string]$GroupId)
    if ($SecurityEnabledInline -eq 'true' -or $SecurityEnabledInline -eq 'false' -or -not [string]::IsNullOrWhiteSpace($GroupTypesInline)) {
        $types = @()
        if (-not [string]::IsNullOrWhiteSpace($GroupTypesInline)) {
            $types = @($GroupTypesInline -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }
        return @{
            groupTypes      = $types
            securityEnabled = ($SecurityEnabledInline -eq 'true')
        }
    }
    return Get-MgGroup -GroupId $GroupId -Property 'displayName', 'groupTypes', 'securityEnabled' -ErrorAction Stop
}

function Read-MemberIdList {
    param([string]$IdsPath, [string]$InlineIds)
    if (-not [string]::IsNullOrWhiteSpace($IdsPath)) {
        if (-not (Test-Path -LiteralPath $IdsPath)) {
            throw "Member-IDs-Datei nicht gefunden: $IdsPath"
        }
        $raw = Get-Content -LiteralPath $IdsPath -Raw -Encoding UTF8
        $parsed = $raw | ConvertFrom-Json
        return @($parsed | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    return @($InlineIds -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

$idList = @()
try {
    $idList = @(Read-MemberIdList -IdsPath $MemberIdsPath -InlineIds $UserIds)
} catch {
    Write-AddMembersJsonResult @{
        status  = 'error'
        message = $_.Exception.Message
        groupId = $GroupId
        added   = 0
        skipped = 0
        failed  = 0
        errors  = @()
    } 1
}

if ($DeviceMembers) {
    try {
        $groupMeta = Get-GroupMetaForDeviceCheck -GroupTypesInline $GroupTypes -SecurityEnabledInline $SecurityEnabled -GroupId $GroupId
        $check = Test-GroupAcceptsDeviceMembers -GroupMeta $groupMeta
        if (-not $check.ok) {
            Write-AddMembersJsonResult @{
                status  = 'error'
                message = [string]$check.message
                groupId = $GroupId
                added   = 0
                skipped = 0
                failed  = 0
                errors  = @()
            } 1
        }
    } catch {
        $detail = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $detail += " $($_.ErrorDetails.Message)" }
        Write-AddMembersJsonResult @{
            status  = 'error'
            message = "Gruppe konnte nicht geprueft werden (ID: $GroupId): $detail"
            groupId = $GroupId
            added   = 0
            skipped = 0
            failed  = 0
            errors  = @()
        } 1
    }
}

if ($idList.Count -eq 0) {
    Write-AddMembersJsonResult @{
        status  = 'error'
        message = 'Keine Member-IDs uebergeben'
        groupId = $GroupId
        added   = 0
        skipped = 0
        failed  = 0
        errors  = @()
    } 1
}

$added = 0
$skipped = 0
$failed = 0
$errorItems = New-Object System.Collections.Generic.List[hashtable]

foreach ($uid in $idList) {
    Write-Host "Mitglied hinzufuegen: $uid"
    try {
        $refPath = "/v1.0/groups/$GroupId/members/`$ref"
        $payload = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$uid" }
        Invoke-MgGraphRequest -Method POST -Uri $refPath -Body $payload -ErrorAction Stop
        $added++
    } catch {
        $raw = "$($_.Exception.Message)"
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $raw += " $($_.ErrorDetails.Message)" }
        if (Test-IsAlreadyMemberError $raw) {
            $skipped++
            Write-Host "Uebersprungen (bereits Mitglied): $uid"
        } else {
            $failed++
            $errorItems.Add(@{ userId = $uid; message = $raw })
            Write-Host "FEHLER: $raw"
        }
    }
}

$status = if ($failed -gt 0) { "partial" } else { "ok" }
$result = @{
    status   = $status
    message  = "Hinzugefuegt: $added, uebersprungen: $skipped, fehlgeschlagen: $failed"
    groupId  = $GroupId
    added    = $added
    skipped  = $skipped
    failed   = $failed
    errors   = @($errorItems)
} | ConvertTo-Json -Depth 6 -Compress

Write-Output "###JSON_START###"
Write-Output $result
Write-Output "###JSON_END###"
exit 0
