# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Liest die Ausfuehrungs-Zustaende (pro Geraet) eines Intune-Plattform-Scripts.
param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptId
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$__mg365ScriptsRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__mg365ScriptsRoot 'Mg365-GraphModules.ps1')

function Write-JsonResult {
    param([hashtable]$Payload, [int]$ExitCode = 0)
    $json = $Payload | ConvertTo-Json -Depth 5 -Compress
    Write-Output "###JSON_START###"
    Write-Output $json
    Write-Output "###JSON_END###"
    exit $ExitCode
}

$__ms365ConnRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__ms365ConnRoot 'Connect-Mg365App.ps1')
Write-Host "Verbinde mit Microsoft Graph..."
try {
    Connect-Mg365App -ErrorAction Stop
} catch {
    Write-JsonResult @{ status = "error"; message = "Verbindung fehlgeschlagen: $($_.Exception.Message)"; states = @() } 1
}

$sid = $ScriptId.Trim()
if (-not $sid) {
    Write-JsonResult @{ status = "error"; message = "ScriptId fehlt"; states = @() } 1
}

try {
    Write-Host "Lade Ausfuehrungs-Zustaende fuer Script $sid ..."
    $uri = "/beta/deviceManagement/deviceManagementScripts/$sid/deviceRunStates?`$expand=managedDevice(`$select=deviceName)"
    $states = @()
    do {
        $resp = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
        foreach ($s in @($resp.value)) {
            $states += @{
                deviceName       = if ($s.managedDevice) { [string]$s.managedDevice.deviceName } else { '' }
                runState         = [string]$s.runState
                resultMessage    = [string]$s.resultMessage
                lastStateUpdate  = [string]$s.lastStateUpdateDateTime
                errorCode        = $s.errorCode
            }
        }
        $uri = [string]$resp.'@odata.nextLink'
    } while ($uri)

    Write-JsonResult @{
        status   = "ok"
        message  = "$($states.Count) Geraete-Zustaende geladen"
        scriptId = $sid
        states   = $states
    } 0
} catch {
    Write-Host "FEHLER: $($_.Exception.Message)"
    Write-JsonResult @{
        status   = "error"
        message  = "Zustaende konnten nicht geladen werden: $($_.Exception.Message)"
        states   = @()
    } 1
}
