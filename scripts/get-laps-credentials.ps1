# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Reads Windows LAPS local admin credentials from Entra (by azureADDeviceId).
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
    $json = $Obj | ConvertTo-Json -Depth 6 -Compress
    Write-Output "###JSON_START###"
    Write-Output $json
    Write-Output "###JSON_END###"
}

# Read a property from Graph hashtable or PSCustomObject responses.
function Read-GraphProp {
    param($Obj, [string]$Key)
    if ($null -eq $Obj) { return $null }
    if ($Obj -is [System.Collections.IDictionary]) { return $Obj[$Key] }
    return $Obj.$Key
}

# LAPS passwords are UTF-16 LE strings stored as Base64 in Graph.
function Decode-LapsPassword {
    param([string]$B64)
    if (-not $B64) { return '' }
    try {
        return [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($B64))
    } catch {
        return ''
    }
}

Write-Host "Verbinde mit Microsoft Graph..."
try {
    Connect-Mg365App -ErrorAction Stop
} catch {
    Write-JsonResult @{ status = "error"; message = "Verbindung fehlgeschlagen: $($_.Exception.Message)"; credentials = @(); hasLaps = $false }
    exit 1
}

$aid = $AzureAdDeviceId.Trim()
if (-not $aid) {
    Write-JsonResult @{ status = "error"; message = "AzureAdDeviceId erforderlich"; credentials = @(); hasLaps = $false }
    exit 1
}

$graphHeaders = @{
    'User-Agent'         = 'MS365-Manager/LAPS'
    'ocp-client-name'    = 'Microsoft365-Manager'
    'ocp-client-version' = '1.0'
}

try {
    $uri = "/v1.0/directory/deviceLocalCredentials/$aid`?`$select=credentials,deviceName,lastBackupDateTime,refreshDateTime"
    Write-Host "Lese LAPS-Credentials für deviceId $aid ..."
    $resp = Invoke-MgGraphRequest -Method GET -Uri $uri -Headers $graphHeaders -OutputType HashTable -ErrorAction Stop

    if ($null -eq $resp) {
        Write-JsonResult @{
            status      = "ok"
            hasLaps     = $false
            message     = "Kein LAPS-Passwort in Entra für dieses Gerät gespeichert."
            credentials = @()
            count       = 0
        }
        exit 0
    }

    $info = $resp
    $wrapped = Read-GraphProp $resp 'value'
    if ($null -ne $wrapped) { $info = $wrapped }

    $rawCreds = @(Read-GraphProp $info 'credentials' | Where-Object { $null -ne $_ })
    $decoded = New-Object System.Collections.Generic.List[object]
    foreach ($c in $rawCreds) {
        $decoded.Add(@{
            accountName    = [string](Read-GraphProp $c 'accountName')
            accountSid     = [string](Read-GraphProp $c 'accountSid')
            backupDateTime = [string](Read-GraphProp $c 'backupDateTime')
            password       = (Decode-LapsPassword ([string](Read-GraphProp $c 'passwordBase64')))
        })
    }

    # Mark newest credential per account as current.
    $seen = @{}
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($item in ($decoded | Sort-Object { Read-GraphProp $_ 'backupDateTime' } -Descending)) {
        $name = [string](Read-GraphProp $item 'accountName')
        if (-not $name) { $name = '_' }
        $isCurrent = -not $seen.ContainsKey($name)
        if ($isCurrent) { $seen[$name] = $true }
        $out.Add(@{
            accountName    = Read-GraphProp $item 'accountName'
            accountSid     = Read-GraphProp $item 'accountSid'
            backupDateTime = Read-GraphProp $item 'backupDateTime'
            password       = Read-GraphProp $item 'password'
            isCurrent      = $isCurrent
        })
    }

    Write-Host "LAPS-Credentials gefunden: $($out.Count)"
    Write-JsonResult @{
        status             = "ok"
        hasLaps            = ($out.Count -gt 0)
        deviceName         = [string](Read-GraphProp $info 'deviceName')
        lastBackupDateTime = [string](Read-GraphProp $info 'lastBackupDateTime')
        credentials        = $out.ToArray()
        count              = $out.Count
    }
    exit 0
} catch {
    $raw = "$($_.Exception.Message)"
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $raw += " $($_.ErrorDetails.Message)" }
    if ($raw -match '404|NotFound|ResourceNotFound|does not exist|nicht gefunden') {
        Write-JsonResult @{
            status      = "ok"
            hasLaps     = $false
            message     = "Kein LAPS-Passwort in Entra für dieses Gerät gespeichert."
            credentials = @()
            count       = 0
        }
        exit 0
    }
    Write-Host "FEHLER: $raw"
    Write-JsonResult @{ status = "error"; message = "Abruf fehlgeschlagen: $raw"; credentials = @(); hasLaps = $false }
    exit 1
}
