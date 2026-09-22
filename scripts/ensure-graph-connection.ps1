# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Stellt EINE Graph-Verbindung her (interaktiver Browser-Login) und fuellt den Token-Cache,
# bevor die Daten-Scripts parallel laufen. Verhindert mehrfache Anmelde-Vorgaenge.
# Ausgabe: JSON an stdout mit Sentry-Markierungen.

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$__ms365ConnRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__ms365ConnRoot 'Mg365-GraphModules.ps1')
. (Join-Path $__ms365ConnRoot 'Connect-Mg365App.ps1')

try {
    Connect-Mg365App -ErrorAction Stop
    # Default-Domain des Tenants ist die aktive Domain fuer alle UPN-Operationen.
    # Fallback-Kette: VerifiedDomains(IsDefault) -> erste VerifiedDomain -> TenantId.
    $tenantDomain = ""
    try {
        Ensure-Mg365GraphModule -Name 'Microsoft.Graph.Identity.DirectoryManagement'
        $org = Get-MgOrganization -Top 1 -Property VerifiedDomains -ErrorAction Stop
        $tenantDomain = ($org.VerifiedDomains | Where-Object { $_.IsDefault -eq $true } | Select-Object -ExpandProperty Name -First 1)
        if (-not $tenantDomain -and $org.VerifiedDomains) { $tenantDomain = [string]$org.VerifiedDomains[0].Name }
    } catch {
        Write-Host "Warnung: Default-Domain konnte nicht ermittelt werden: $($_.Exception.Message)"
    }
    if (-not $tenantDomain) {
        try {
            $ctx = Get-MgContext
            if ($ctx) { $tenantDomain = [string]$ctx.TenantId }
        } catch {}
    }
    Write-Host "Anmeldung erfolgreich."
    $result = @{ status = "ok"; message = "Verbunden mit Microsoft Graph."; tenantDomain = $tenantDomain } | ConvertTo-Json -Compress
    Write-Output "###JSON_START###"
    Write-Output $result
    Write-Output "###JSON_END###"
    exit 0
} catch {
    $result = @{ status = "error"; message = "Verbindung fehlgeschlagen: $($_.Exception.Message)"; tenantDomain = "" } | ConvertTo-Json -Compress
    Write-Output "###JSON_START###"
    Write-Output $result
    Write-Output "###JSON_END###"
    exit 1
}
