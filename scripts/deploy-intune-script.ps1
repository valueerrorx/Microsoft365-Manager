# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Laedt ein PowerShell-Plattform-Script nach Intune (deviceManagementScripts) hoch
# und weist es einer Entra-Gruppe zu. Der Script-Inhalt wird Base64-kodiert uebergeben.
param(
    [Parameter(Mandatory = $true)]
    [string]$DisplayName,

    [Parameter(Mandatory = $true)]
    [string]$ScriptContentBase64,

    [Parameter(Mandatory = $true)]
    [string]$GroupId,

    [Parameter(Mandatory = $false)]
    [string]$Description = 'Erstellt mit Microsoft365-Manager',

    [Parameter(Mandatory = $false)]
    [string]$FileName = 'script.ps1'
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$__mg365ScriptsRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__mg365ScriptsRoot 'Mg365-GraphModules.ps1')

function Write-JsonResult {
    param([hashtable]$Payload, [int]$ExitCode = 0)
    $json = $Payload | ConvertTo-Json -Depth 4 -Compress
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
    Write-JsonResult @{ status = "error"; message = "Verbindung fehlgeschlagen: $($_.Exception.Message)" } 1
}

$gid = $GroupId.Trim()
if (-not $gid) {
    Write-JsonResult @{ status = "error"; message = "GroupId fehlt" } 1
}
if (-not $ScriptContentBase64.Trim()) {
    Write-JsonResult @{ status = "error"; message = "Script-Inhalt leer" } 1
}

try {
    # Intune verlangt den Script-Inhalt selbst Base64-kodiert; wir bekommen ihn bereits
    # so uebergeben und reichen ihn unveraendert durch.
    $body = @{
        '@odata.type'         = '#microsoft.graph.deviceManagementScript'
        displayName           = $DisplayName
        description           = $Description
        runAsAccount          = 'system'
        enforceSignatureCheck = $false
        fileName              = $FileName
        scriptContent         = $ScriptContentBase64
    } | ConvertTo-Json -Depth 4

    Write-Host "Lade Script '$DisplayName' nach Intune hoch..."
    $created = Invoke-MgGraphRequest -Method POST -Uri "/beta/deviceManagement/deviceManagementScripts" -Body $body -ContentType 'application/json' -ErrorAction Stop
    $scriptId = [string]$created.id
    if (-not $scriptId) {
        Write-JsonResult @{ status = "error"; message = "Kein Script-ID von Intune erhalten" } 1
    }

    Write-Host "Weise Script der Gruppe $gid zu..."
    $assignBody = @{
        deviceManagementScriptGroupAssignments = @(
            @{
                '@odata.type' = '#microsoft.graph.deviceManagementScriptGroupAssignment'
                targetGroupId = $gid
            }
        )
    } | ConvertTo-Json -Depth 5

    Invoke-MgGraphRequest -Method POST -Uri "/beta/deviceManagement/deviceManagementScripts/$scriptId/assign" -Body $assignBody -ContentType 'application/json' -ErrorAction Stop

    Write-JsonResult @{
        status      = "ok"
        message     = "Script '$DisplayName' hochgeladen und Gruppe zugewiesen. Ausfuehrung beim naechsten Geraete-Check-in."
        scriptId    = $scriptId
        displayName = $DisplayName
        groupId     = $gid
    } 0
} catch {
    Write-Host "FEHLER: $($_.Exception.Message)"
    Write-JsonResult @{
        status  = "error"
        message = "Upload/Zuweisung fehlgeschlagen: $($_.Exception.Message)"
    } 1
}
