# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Removes a user from an Entra directory role (by role template id)
param(
    [Parameter(Mandatory = $true)]
    [string]$RoleTemplateId,
    [Parameter(Mandatory = $true)]
    [string]$UserId
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

function Ensure-Module {
    param([string]$Name)
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
    try { Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -Confirm:$false -ErrorAction Stop | Out-Null } catch {}
    try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue } catch {}
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Host "Installiere Modul: $Name"
        Install-Module $Name -Force -Scope CurrentUser -AllowClobber -Confirm:$false -ErrorAction Stop
    }
    Import-Module $Name -Force -ErrorAction Stop
}

Ensure-Module "Microsoft.Graph.Identity.DirectoryManagement"

$__ms365ConnRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$__dirRoleHelper = Join-Path $__ms365ConnRoot 'DirectoryRole-Mg365.ps1'
if (-not (Test-Path -LiteralPath $__dirRoleHelper)) { throw "DirectoryRole-Mg365.ps1 fehlt (erwartet in: $__ms365ConnRoot)" }
. $__dirRoleHelper
if (-not (Get-Command Get-ActivatedDirectoryRoleByTemplateId -ErrorAction SilentlyContinue)) { throw "DirectoryRole-Mg365.ps1 konnte nicht geladen werden" }
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

$uid = $UserId.Trim()
$tid = $RoleTemplateId.Trim()
if (-not $uid -or -not $tid) {
    $result = @{ status = "error"; message = "RoleTemplateId und UserId erforderlich" } | ConvertTo-Json -Compress
    Write-Output "###JSON_START###"
    Write-Output $result
    Write-Output "###JSON_END###"
    exit 1
}

try {
    $dirRole = Get-ActivatedDirectoryRoleByTemplateId -TemplateId $tid
    if (-not $dirRole) {
        throw "Rolle ist im Tenant nicht aktiviert (Template: $tid)"
    }
    $refPath = "/v1.0/directoryRoles/$($dirRole.Id)/members/$uid/`$ref"
    Invoke-MgGraphRequest -Method DELETE -Uri $refPath -ErrorAction Stop
    $result = @{
        status          = "ok"
        message         = "Benutzer aus Rolle entfernt"
        roleTemplateId  = $tid
        directoryRoleId = $dirRole.Id
        userId          = $uid
    } | ConvertTo-Json -Compress
    Write-Output "###JSON_START###"
    Write-Output $result
    Write-Output "###JSON_END###"
    exit 0
} catch {
    $result = @{
        status         = "error"
        message        = "Fehler: $($_.Exception.Message)"
        roleTemplateId = $tid
        userId         = $uid
    } | ConvertTo-Json -Compress
    Write-Output "###JSON_START###"
    Write-Output $result
    Write-Output "###JSON_END###"
    exit 1
}
