# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Shared Graph login; never Import-Module Microsoft.Graph.Authentication -Force after another Graph module loaded it (same assembly twice -> error on Linux/Windows).
function Connect-Mg365App {
    [CmdletBinding()]
    param()
    if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
            try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
            try { Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -Confirm:$false -ErrorAction SilentlyContinue | Out-Null } catch {}
            try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue } catch {}
            Write-Host "Installiere Modul: Microsoft.Graph.Authentication"
            Install-Module Microsoft.Graph.Authentication -Force -Scope CurrentUser -AllowClobber -Confirm:$false -ErrorAction Stop
        }
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    }
    $scopes = @(
        'Device.Read.All',
        'DeviceManagementManagedDevices.Read.All',
        'DeviceManagementManagedDevices.PrivilegedOperations.All',
        'Directory.ReadWrite.All',
        'Group.ReadWrite.All',
        'GroupMember.ReadWrite.All',
        'Organization.Read.All',
        'User.Read.All',
        'User.ReadWrite.All',
        'UserAuthenticationMethod.ReadWrite.All',
        'RoleManagement.ReadWrite.Directory'
    )
    $authRecordPath = Join-Path $HOME '.mg\mg.authrecord.json'
    $useDeviceCode = $env:MS365_ELECTRON_APP -eq '1'
    if ($useDeviceCode) {
        # Nur aus Cache reconnecten wenn Auth-Record existiert; sonst WAM ohne HWND (120s-Timeout).
        if (Test-Path -LiteralPath $authRecordPath) {
            Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop | Out-Null
            if (Get-MgContext) {
                Write-Host "Bestehende Anmeldung wiederverwendet."
                return
            }
            throw "Token-Cache vorhanden, aber keine aktive Sitzung."
        }
        Write-Host "Device-Code-Anmeldung - Browser oeffnet sich automatisch..." -ForegroundColor Yellow
        Write-Host "Code steht unten im Ausgabefenster; auf der Seite eingeben und anmelden." -ForegroundColor Yellow
        Connect-MgGraph -Scopes $scopes -UseDeviceCode -NoWelcome -ClientTimeout 600 -ErrorAction Stop
        Write-Host "Anmeldung erfolgreich."
        return
    }
    Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop
}
