# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Lists BitLocker recovery keys for an Entra device (by azureADDeviceId / Entra deviceId).
param(
    [Parameter(Mandatory = $true)]
    [string]$AzureAdDeviceId
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$__mg365ScriptsRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__mg365ScriptsRoot 'Mg365-GraphModules.ps1')

$__ms365ConnRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__ms365ConnRoot 'Connect-Mg365App.ps1')

function Write-JsonResult {
    param([hashtable]$Obj)
    $json = $Obj | ConvertTo-Json -Depth 5 -Compress
    Write-Output "###JSON_START###"
    Write-Output $json
    Write-Output "###JSON_END###"
}

Write-Host "Verbinde mit Microsoft Graph..."
try {
    Connect-Mg365App -ErrorAction Stop
} catch {
    Write-JsonResult @{ status = "error"; message = "Verbindung fehlgeschlagen: $($_.Exception.Message)"; keys = @() }
    exit 1
}

$aid = $AzureAdDeviceId.Trim()
if (-not $aid) {
    Write-JsonResult @{ status = "error"; message = "AzureAdDeviceId erforderlich"; keys = @() }
    exit 1
}

try {
    $escaped = $aid -replace "'", "''"
    # Recovery keys can only be filtered by deviceId; the key value itself must be fetched per key via $select=key.
    $listUri = "/v1.0/informationProtection/bitlocker/recoveryKeys?`$filter=deviceId eq '$escaped'"
    Write-Host "Suche BitLocker-Recovery-Keys für deviceId $aid ..."
    $listResp = Invoke-MgGraphRequest -Method GET -Uri $listUri -ErrorAction Stop
    $rows = @($listResp.value)

    $keysData = @()
    foreach ($r in $rows) {
        $keyId = [string]$r.id
        $keyValue = $null
        try {
            $detail = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/informationProtection/bitlocker/recoveryKeys/$keyId`?`$select=key" -ErrorAction Stop
            $keyValue = [string]$detail.key
        } catch {
            Write-Host "Hinweis: Key-Wert für $keyId nicht abrufbar: $($_.Exception.Message)"
        }
        $keysData += @{
            id                = $keyId
            key               = $keyValue
            volumeType        = [string]$r.volumeType
            createdDateTime   = [string]$r.createdDateTime
        }
    }

    Write-Host "BitLocker-Keys gefunden: $($keysData.Count)"
    Write-JsonResult @{ status = "ok"; keys = @($keysData); count = $keysData.Count }
    exit 0
} catch {
    Write-Host "FEHLER: $($_.Exception.Message)"
    Write-JsonResult @{ status = "error"; message = "Abruf fehlgeschlagen: $($_.Exception.Message)"; keys = @() }
    exit 1
}
