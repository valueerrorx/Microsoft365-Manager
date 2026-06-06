# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Writes auth trace lines visible in Electron log console and pwsh output panel.
function Write-Mg365AuthLog {
    param([string]$Message)
    Write-Host "[MG365-AUTH] $Message"
}

# Shared Graph login; never Import-Module Microsoft.Graph.Authentication -Force after another Graph module loaded it (same assembly twice -> error on Linux/Windows).
function Connect-Mg365App {
    [CmdletBinding()]
    param()
    Write-Mg365AuthLog "Connect-Mg365App start (PID=$PID)"
    Write-Mg365AuthLog "HOME=$HOME USERPROFILE=$env:USERPROFILE MS365_ELECTRON_APP=$env:MS365_ELECTRON_APP MS365_GRAPH_SESSION_WARM=$env:MS365_GRAPH_SESSION_WARM"
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
    if ($env:MS365_GRAPH_ACCESS_TOKEN) {
        Write-Mg365AuthLog "Connect-MgGraph -AccessToken (Electron Device-Code)"
        try {
            $secureToken = ConvertTo-SecureString -String $env:MS365_GRAPH_ACCESS_TOKEN -AsPlainText -Force
            Connect-MgGraph -AccessToken $secureToken -NoWelcome -ErrorAction Stop
            $ctxToken = Get-MgContext
            if ($ctxToken) {
                Write-Mg365AuthLog "Connect OK account=$($ctxToken.Account) tenant=$($ctxToken.TenantId) scopes=$($ctxToken.Scopes -join ',')"
            }
            Write-Host "Anmeldung erfolgreich."
        } catch {
            Write-Mg365AuthLog "Connect FEHLER: $($_.Exception.Message)"
            throw
        }
        return
    }
    $useDeviceCode = $env:MS365_ELECTRON_APP -eq '1'
    Write-Mg365AuthLog "useDeviceCode=$useDeviceCode scopeCount=$($scopes.Count)"
    if ($useDeviceCode) {
        $authRecordPath = Join-Path $HOME '.mg\mg.authrecord.json'
        $hasCache = Test-Path -LiteralPath $authRecordPath
        Write-Mg365AuthLog "authRecordPath=$authRecordPath exists=$hasCache"
        if (-not $hasCache) {
            Write-Host "Device-Code-Anmeldung - Browser oeffnet sich automatisch..." -ForegroundColor Yellow
            Write-Host "Code steht unten im Ausgabefenster; auf der Seite eingeben und anmelden." -ForegroundColor Yellow
        } else {
            Write-Mg365AuthLog "Cache vorhanden — Connect-MgGraph -UseDeviceCode (MSAL soll Cache still nutzen)"
        }
        Write-Mg365AuthLog "Connect-MgGraph -UseDeviceCode start (ClientTimeout=600)"
        try {
            Connect-MgGraph -Scopes $scopes -UseDeviceCode -NoWelcome -ClientTimeout 600 -ErrorAction Stop
            $ctx = Get-MgContext
            if ($ctx) {
                Write-Mg365AuthLog "Connect OK account=$($ctx.Account) tenant=$($ctx.TenantId) scopes=$($ctx.Scopes -join ',')"
            } else {
                Write-Mg365AuthLog "Connect fertig aber Get-MgContext ist leer"
            }
            Write-Host "Anmeldung erfolgreich."
        } catch {
            Write-Mg365AuthLog "Connect FEHLER: $($_.Exception.Message)"
            throw
        }
        return
    }
    Write-Mg365AuthLog "Connect-MgGraph Browser-Modus (Linux)"
    Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop
    $ctxLinux = Get-MgContext
    if ($ctxLinux) {
        Write-Mg365AuthLog "Connect OK account=$($ctxLinux.Account) tenant=$($ctxLinux.TenantId)"
    }
}
