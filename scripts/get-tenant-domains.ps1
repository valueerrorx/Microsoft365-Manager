# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Listet alle verifizierten Domains des Tenants (fuer die Domain-Auswahl in der Sidebar)
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$__mg365ScriptsRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__mg365ScriptsRoot 'Mg365-GraphModules.ps1')

$__ms365ConnRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__ms365ConnRoot 'Connect-Mg365App.ps1')
Write-Host "Verbinde mit Microsoft Graph..."

try {
    Connect-Mg365App -ErrorAction Stop
} catch {
    $result = @{
        status  = "error"
        message = "Verbindung fehlgeschlagen: $($_.Exception.Message)"
        domains = @()
    } | ConvertTo-Json -Depth 3 -Compress
    Write-Output "###JSON_START###"
    Write-Output $result
    Write-Output "###JSON_END###"
    exit 1
}

Ensure-Module "Microsoft.Graph.Identity.DirectoryManagement"

$domainsData = @()
$defaultDomain = ""
try {
    Write-Host "Lade Domains..."
    $org = Get-MgOrganization -Top 1 -Property VerifiedDomains -ErrorAction Stop
    foreach ($d in $org.VerifiedDomains) {
        # isInitial = die unveraenderliche *.onmicrosoft.com Domain des Tenants
        $domainsData += @{
            name      = [string]$d.Name
            isDefault = [bool]$d.IsDefault
            isInitial = [bool]$d.IsInitial
            type      = [string]$d.Type
        }
        if ($d.IsDefault -eq $true) { $defaultDomain = [string]$d.Name }
    }
    if (-not $defaultDomain -and $domainsData.Count -gt 0) { $defaultDomain = $domainsData[0].name }
    Write-Host "Domains geladen: $($domainsData.Count)"
} catch {
    $result = @{
        status  = "error"
        message = "Fehler beim Laden der Domains: $($_.Exception.Message)"
        domains = @()
    } | ConvertTo-Json -Depth 4 -Compress
    Write-Output "###JSON_START###"
    Write-Output $result
    Write-Output "###JSON_END###"
    exit 1
}

$output = @{
    status        = "ok"
    domains       = $domainsData
    defaultDomain = $defaultDomain
    count         = $domainsData.Count
} | ConvertTo-Json -Depth 6 -Compress

Write-Output "###JSON_START###"
Write-Output $output
Write-Output "###JSON_END###"
