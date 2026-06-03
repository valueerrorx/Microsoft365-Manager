# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Clears Microsoft Graph / MSAL token cache for this app (sign-out).

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

function Write-JsonResult {
    param([hashtable]$Payload)
    $json = $Payload | ConvertTo-Json -Compress
    Write-Output "###JSON_START###"
    Write-Output $json
    Write-Output "###JSON_END###"
}

try {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        Write-JsonResult @{ status = 'ok'; message = 'Keine Graph-Sitzung im Cache (Modul nicht installiert).' }
        exit 0
    }
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    if (Get-Command Disconnect-MgGraph -ErrorAction SilentlyContinue) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    Write-JsonResult @{ status = 'ok'; message = 'Microsoft Graph abgemeldet — Token-Cache geleert.' }
    exit 0
} catch {
    $errMsg = [string]$_.Exception.Message
    Write-JsonResult @{ status = 'error'; message = "Abmelden fehlgeschlagen: $errMsg" }
    exit 1
}
