# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Pinned Graph SDK version (all Microsoft.Graph.* modules must match to avoid duplicate-assembly load errors).
$script:Mg365GraphSdkVersion = [version]'2.36.1'

function Ensure-Mg365GraphModule {
    param([Parameter(Mandatory = $true)][string]$Name)

    $isGraph = $Name -like 'Microsoft.Graph*'
    $ver = if ($isGraph) { $script:Mg365GraphSdkVersion } else { $null }

    $loaded = Get-Module -Name $Name -ErrorAction SilentlyContinue
    if ($loaded) {
        if (-not $ver -or $loaded.Version -eq $ver) { return }
        Remove-Module -Name $Name -Force -ErrorAction SilentlyContinue
    }

    $available = if ($ver) {
        @(Get-Module -ListAvailable -Name $Name | Where-Object { $_.Version -eq $ver })
    } else {
        @(Get-Module -ListAvailable -Name $Name)
    }

    # Bereits installiert → direkt importieren, NuGet/PSGallery-Setup (Netzwerk) überspringen.
    if (-not $available.Count) {
        # PackageProvider/Repository nur im Install-Pfad anfassen (sonst Netzwerk-Roundtrip pro Aufruf).
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
        try { Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -Confirm:$false -ErrorAction Stop | Out-Null } catch {}
        try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue } catch {}
        Write-Host "Installiere Modul: $Name$(if ($ver) { " ($ver)" })"
        $installArgs = @{
            Name         = $Name
            Force        = $true
            Scope        = 'CurrentUser'
            AllowClobber = $true
            Confirm      = $false
            ErrorAction  = 'Stop'
        }
        if ($ver) { $installArgs.RequiredVersion = $ver.ToString() }
        Install-Module @installArgs
    }

    if ($ver) {
        Import-Module $Name -RequiredVersion $ver -ErrorAction Stop
    } else {
        Import-Module $Name -Force -ErrorAction Stop
    }
}

function Ensure-Module {
    param([Parameter(Mandatory = $true)][string]$Name)
    Ensure-Mg365GraphModule -Name $Name
}
