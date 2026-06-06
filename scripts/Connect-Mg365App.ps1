# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

$script:Mg365GraphClientId = '14d82eec-204b-4c2f-b7e8-296a70dab67e'

# Resolve a bundled assembly from Microsoft.Graph.Authentication.
function Get-Mg365GraphAssemblyPath {
    param([string]$FileName)
    $mod = Get-Module -ListAvailable Microsoft.Graph.Authentication | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $mod) { return $null }
    $hit = Get-ChildItem -Path $mod.ModuleBase -Recurse -Filter $FileName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { return $hit.FullName }
    return $null
}

# Load a Graph-bundled .NET assembly only when the module did not already register the type.
function Ensure-Mg365GraphAssembly {
    param([string]$FileName, [string]$TypeName)
    if ($TypeName -as [type]) { return }
    $path = Get-Mg365GraphAssemblyPath -FileName $FileName
    if (-not $path) { throw "$FileName nicht gefunden (Microsoft.Graph.Authentication)." }
    Add-Type -Path $path
}

# Windows: Graph SDK forces WAM on first Connect-MgGraph (needs HWND). Use system browser via Azure.Identity, same as Linux.
function Connect-Mg365WindowsBrowserLogin {
    param([string[]]$Scopes)

    Ensure-Mg365GraphAssembly -FileName 'Azure.Core.dll' -TypeName 'Azure.Core.TokenRequestContext'
    Ensure-Mg365GraphAssembly -FileName 'Azure.Identity.dll' -TypeName 'Azure.Identity.InteractiveBrowserCredentialOptions'

    $msScopes = [string[]]@(
        foreach ($s in $Scopes) {
            if ($s -match '^https?://') { $s } else { "https://graph.microsoft.com/$s" }
        }
    )

    $options = [Azure.Identity.InteractiveBrowserCredentialOptions]::new()
    $options.ClientId = $script:Mg365GraphClientId
    $options.TenantId = 'organizations'
    $options.AuthorityHost = [Uri]'https://login.microsoftonline.com'
    $options.TokenCachePersistenceOptions = [Azure.Identity.TokenCachePersistenceOptions]::new()
    $options.TokenCachePersistenceOptions.Name = 'mg.msal.cache'

    $cred = [Azure.Identity.InteractiveBrowserCredential]::new($options)
    $requestContext = [Azure.Core.TokenRequestContext]::new($msScopes)
    $authRecord = $cred.AuthenticateAsync($requestContext, [System.Threading.CancellationToken]::None).GetAwaiter().GetResult()

    $mgDir = Join-Path $HOME '.mg'
    if (-not (Test-Path -LiteralPath $mgDir)) { New-Item -ItemType Directory -Path $mgDir -Force | Out-Null }
    $authPath = Join-Path $mgDir 'mg.authrecord.json'
    $fs = [System.IO.File]::Open($authPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try {
        $authRecord.SerializeAsync($fs).GetAwaiter().GetResult()
    } finally {
        $fs.Dispose()
    }
}

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

    if ($IsWindows) {
        $authRecordPath = Join-Path $HOME '.mg\mg.authrecord.json'
        if (-not (Test-Path -LiteralPath $authRecordPath)) {
            Connect-Mg365WindowsBrowserLogin -Scopes $scopes
        }
    }

    Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop
}
