# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Replaces all user licenses with one SKU (batch GET + Set-MgUserLicense per user)
param(
    [Parameter(Mandatory = $true)]
    [string]$UPNs,

    [Parameter(Mandatory = $true)]
    [string]$SkuId
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$__mg365ScriptsRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__mg365ScriptsRoot 'Mg365-GraphModules.ps1')

function Write-JsonResult {
    param([hashtable]$Payload, [int]$ExitCode = 0)
    $json = $Payload | ConvertTo-Json -Depth 6 -Compress
    Write-Output "###JSON_START###"
    Write-Output $json
    Write-Output "###JSON_END###"
    exit $ExitCode
}

# Builds Set-MgUserLicense args; $null = user already has only the target SKU.
function New-ReplaceLicenseChange {
    param([string]$TargetSku, [array]$CurrentSkuIds)
    $target = [string]$TargetSku
    $current = [System.Collections.Generic.List[string]]::new()
    foreach ($raw in @($CurrentSkuIds)) {
        $id = [string]$raw
        if (-not [string]::IsNullOrWhiteSpace($id)) { [void]$current.Add($id.Trim()) }
    }
    $toRemove = [System.Collections.Generic.List[string]]::new()
    foreach ($id in $current) {
        if ($id -cne $target) { [void]$toRemove.Add($id) }
    }
    $needsAdd = -not $current.Contains($target)
    if ($toRemove.Count -eq 0 -and -not $needsAdd) { return $null }
    $add = @()
    if ($needsAdd) { $add = @(@{ SkuId = $target }) }
    return @{
        AddLicenses    = $add
        RemoveLicenses = [string[]]$toRemove.ToArray()
    }
}

Ensure-Module "Microsoft.Graph.Users"
Ensure-Module "Microsoft.Graph.Users.Actions"

$__ms365ConnRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__ms365ConnRoot 'Connect-Mg365App.ps1')
Write-Host "Verbinde mit Microsoft Graph..."
try {
    Connect-Mg365App -ErrorAction Stop
} catch {
    Write-JsonResult @{
        status      = "error"
        message     = "Verbindung fehlgeschlagen: $($_.Exception.Message)"
        updated     = 0
        failed      = 0
        updatedUpns = @()
        errors      = @()
        skuId       = $SkuId
    } 1
}

$sku = $SkuId.Trim()
if ([string]::IsNullOrWhiteSpace($sku)) {
    Write-JsonResult @{
        status      = "error"
        message     = "Keine SkuId uebergeben"
        updated     = 0
        failed      = 0
        updatedUpns = @()
        errors      = @()
        skuId       = ""
    } 1
}

$upnList = @($UPNs -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

if ($upnList.Count -eq 0) {
    Write-JsonResult @{
        status      = "error"
        message     = "Keine UPNs uebergeben"
        updated     = 0
        failed      = 0
        updatedUpns = @()
        errors      = @()
        skuId       = $sku
    } 1
}

$updatedUpns = New-Object System.Collections.Generic.List[string]
$errorItems = New-Object System.Collections.Generic.List[hashtable]
$batchSize = 20

Write-Host "Ersetze Lizenzen durch $sku fuer $($upnList.Count) Benutzer..."

for ($offset = 0; $offset -lt $upnList.Count; $offset += $batchSize) {
    $end = [Math]::Min($offset + $batchSize - 1, $upnList.Count - 1)
    $chunk = @($upnList[$offset..$end])
    $idToUpn = @{}
    $getRequests = New-Object System.Collections.Generic.List[hashtable]

    for ($i = 0; $i -lt $chunk.Count; $i++) {
        $upn = $chunk[$i]
        $reqId = "g$i"
        $idToUpn[$reqId] = $upn
        $encoded = [uri]::EscapeDataString($upn)
        $getRequests.Add(@{
            id     = $reqId
            method = "GET"
            url    = "/users/$encoded`?`$select=assignedLicenses"
        })
    }

    $upnToSkuIds = @{}
    try {
        $getResp = Invoke-MgGraphRequest -Method POST -Uri '/v1.0/$batch' -Body @{ requests = @($getRequests) } -ErrorAction Stop
        foreach ($r in @($getResp.responses)) {
            $upn = $idToUpn[[string]$r.id]
            if (-not $upn) { continue }
            $statusCode = [int]$r.status
            if ($statusCode -ge 200 -and $statusCode -lt 300 -and $r.body) {
                $ids = [System.Collections.Generic.List[string]]::new()
                if ($r.body.assignedLicenses) {
                    foreach ($lic in @($r.body.assignedLicenses)) {
                        if ($null -ne $lic.skuId) { [void]$ids.Add([string]$lic.skuId) }
                    }
                }
                $upnToSkuIds[$upn] = @($ids.ToArray())
            } else {
                $msg = "HTTP $statusCode"
                if ($r.body -and $r.body.error -and $r.body.error.message) {
                    $msg = [string]$r.body.error.message
                }
                $errorItems.Add(@{ upn = $upn; message = "Lizenzen lesen: $msg" })
                Write-Host "FEHLER ($upn): Lizenzen lesen: $msg"
            }
        }
    } catch {
        $batchErr = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $batchErr += " $($_.ErrorDetails.Message)" }
        foreach ($upn in $chunk) {
            $errorItems.Add(@{ upn = $upn; message = "Lizenzen lesen: $batchErr" })
            Write-Host "FEHLER ($upn): Lizenzen lesen: $batchErr"
        }
        continue
    }

    foreach ($upn in $chunk) {
        if (-not $upnToSkuIds.ContainsKey($upn)) { continue }
        $change = New-ReplaceLicenseChange -TargetSku $sku -CurrentSkuIds $upnToSkuIds[$upn]
        if ($null -eq $change) {
            Write-Host "Uebersprungen (hat bereits nur Ziel-Lizenz): $upn"
            continue
        }
        try {
            Set-MgUserLicense -UserId $upn -AddLicenses $change.AddLicenses -RemoveLicenses $change.RemoveLicenses -ErrorAction Stop
            $updatedUpns.Add($upn)
            Write-Host "Lizenz ersetzt: $upn"
        } catch {
            $msg = $_.Exception.Message
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $msg += " $($_.ErrorDetails.Message)" }
            $errorItems.Add(@{ upn = $upn; message = $msg })
            Write-Host "FEHLER ($upn): $msg"
        }
    }
}

$updated = $updatedUpns.Count
$failed = $errorItems.Count
$status = if ($failed -gt 0 -and $updated -gt 0) { "partial" } elseif ($failed -gt 0) { "error" } else { "ok" }
$message = "Lizenz ersetzt: $updated, fehlgeschlagen: $failed"

Write-JsonResult @{
    status      = $status
    message     = $message
    updated     = $updated
    failed      = $failed
    updatedUpns = @($updatedUpns)
    errors      = @($errorItems)
    skuId       = $sku
} 0
