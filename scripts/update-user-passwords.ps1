# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Erstellt oder aktualisiert Benutzer basierend auf einer CSV-Datei und weist Lizenzen zu.

param(
    [Parameter(Mandatory = $false)]
    [string]$CSVPath = $env:CSV_PATH,

    [Parameter(Mandatory = $false)]
    [ValidateSet('givenFirst','surnameFirst')]
    [string]$UpnOrder = 'givenFirst',

    # SKU der Lizenz, die neuen Benutzern zugewiesen wird (leer = keine Lizenz).
    [Parameter(Mandatory = $false)]
    [string]$LicenseSkuId = '',

    # Aktive Domain aus der UI; leer = Default-Domain des Tenants ermitteln.
    [Parameter(Mandatory = $false)]
    [string]$TenantDomain = ''
)

# Unterdrücke Welcome-Message und Telemetrie
$PSDefaultParameterValues['Out-Default:OutVariable'] = $null
$ErrorActionPreference = 'Continue'

# Falls CSVPath leer ist, verwende Umgebungsvariable
if ([string]::IsNullOrWhiteSpace($CSVPath) -and $env:CSV_PATH) {
    $CSVPath = $env:CSV_PATH
}

try {
    $CSVFilePath = (Resolve-Path -Path $CSVPath -ErrorAction Stop).Path
} catch {
    Write-Error "CSV-Pfad ungültig: $CSVPath"
    return
}

if (-not (Test-Path -Path $CSVFilePath)) {
    Write-Error "CSV-Datei nicht gefunden unter: $($CSVFilePath)"
    return
}

$__ms365ConnRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $__ms365ConnRoot 'Mg365-GraphModules.ps1')
Ensure-Mg365GraphModule -Name 'Microsoft.Graph.Users'
Ensure-Mg365GraphModule -Name 'Microsoft.Graph.Users.Actions'
Ensure-Mg365GraphModule -Name 'Microsoft.Graph.Identity.DirectoryManagement'

. (Join-Path $__ms365ConnRoot 'Connect-Mg365App.ps1')
Connect-Mg365App

# Tenant-Domain: bevorzugt die in der UI angezeigte aktive Domain, damit UPN-Vorschau
# und tatsaechlich angelegter UPN nicht auseinanderlaufen.
$tenantDomain = $TenantDomain.Trim()
if ($tenantDomain) {
    Write-Host "Tenant-Domain aus UI: $tenantDomain" -ForegroundColor Cyan
}
try {
    if (-not $tenantDomain) {
        $org = Get-MgOrganization -Top 1
        $tenantDomain = $org.VerifiedDomains | Where-Object { $_.IsDefault -eq $true } | Select-Object -ExpandProperty Name
        if (-not $tenantDomain) {
            $tenantDomain = $org.VerifiedDomains[0].Name
        }
        Write-Host "Tenant-Domain ermittelt: $tenantDomain" -ForegroundColor Cyan
    }
} catch {
    Write-Error "Konnte Tenant-Domain nicht ermitteln: $($_.Exception.Message)"
    return
}

# Lizenz kommt aus der UI-Auswahl (-LicenseSkuId); leer = keine Lizenzzuweisung.
$licenseSkuId = $LicenseSkuId.Trim()
if ([string]::IsNullOrWhiteSpace($licenseSkuId)) {
    $licenseSkuId = $null
    Write-Host "Keine Lizenz ausgewaehlt - Benutzer werden ohne Lizenz angelegt." -ForegroundColor Yellow
}

# Funktion: Normalisiere String für UPN (lowercase, alle Sonderzeichen ersetzen)
function Normalize-ForUPN {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    
    # Ersetze zuerst alle Sonderzeichen (auch Großbuchstaben-Varianten)
    # Deutsche Umlaute
    $Text = $Text -replace '[äÄ]', 'ae'
    $Text = $Text -replace '[öÖ]', 'oe'
    $Text = $Text -replace '[üÜ]', 'ue'
    $Text = $Text -replace '[ß]', 'ss'
    # Französische/Italienische Akzente
    $Text = $Text -replace '[àáâãÀÁÂÃ]', 'a'
    $Text = $Text -replace '[èéêëÈÉÊË]', 'e'
    $Text = $Text -replace '[ìíîïÌÍÎÏ]', 'i'
    $Text = $Text -replace '[òóôõÒÓÔÕ]', 'o'
    $Text = $Text -replace '[ùúûÙÚÛ]', 'u'
    $Text = $Text -replace '[ýÿÝŸ]', 'y'
    $Text = $Text -replace '[çÇ]', 'c'
    $Text = $Text -replace '[ñÑ]', 'n'
    
    # Dann zu lowercase konvertieren
    $Text = $Text.ToLower()
    
    # Zum Schluss alle verbleibenden Sonderzeichen entfernen (außer a-z, 0-9, Punkt)
    $Text = $Text -replace '[^a-z0-9\.]', ''
    
    return $Text
}

# Stelle sicher, dass CSV als UTF-8 gelesen wird
$Utf8Encoding = [System.Text.Encoding]::UTF8
$csvContent = Get-Content -Path $CSVFilePath -Raw -Encoding UTF8
# Entferne BOM falls vorhanden
if ($csvContent.StartsWith([char]0xFEFF)) {
    $csvContent = $csvContent.Substring(1)
}
# Konvertiere zu CSV-Objekt
$csvData = $csvContent | ConvertFrom-Csv -Delimiter ';'

$failedUsers = @()

foreach ($row in $csvData) {
    $Vorname = "$($row.Vorname)".Trim()
    $Nachname = "$($row.Nachname)".Trim()
    $Abteilung = "$($row.Abteilung)".Trim()
    $OfficeLocation = "$($row.'Büro')".Trim()
    if ([string]::IsNullOrWhiteSpace($OfficeLocation)) { $OfficeLocation = "$($row.Buero)".Trim() }
    if ([string]::IsNullOrWhiteSpace($OfficeLocation)) { $OfficeLocation = "$($row.OfficeLocation)".Trim() }
    $Password = "$($row.NewPassword)".Trim()
    
    # Verwende bereits normalisierte Werte aus CSV, falls vorhanden
    $VornameNormalized = "$($row.VornameNormalized)".Trim()
    $NachnameNormalized = "$($row.NachnameNormalized)".Trim()
    
    # Falls normalisierte Werte nicht vorhanden, normalisiere selbst (für Rückwärtskompatibilität)
    if ([string]::IsNullOrWhiteSpace($VornameNormalized)) {
        $VornameNormalized = Normalize-ForUPN $Vorname
    }
    if ([string]::IsNullOrWhiteSpace($NachnameNormalized)) {
        $NachnameNormalized = Normalize-ForUPN $Nachname
    }
    
    $RawValue = "$($row.ForceChange)".Trim()
    $ForceChange = switch ($RawValue) {
        "1" { $true }
        default { $false }
    }

    # Validiere erforderliche Felder
    if ([string]::IsNullOrWhiteSpace($Vorname) -or [string]::IsNullOrWhiteSpace($Nachname) -or [string]::IsNullOrWhiteSpace($Password)) {
        Write-Host "FEHLER: Vorname, Nachname oder Passwort fehlt für: $Vorname $Nachname" -ForegroundColor Red
        continue
    }

    # Build UserPrincipalName from normalized parts; order comes from -UpnOrder (default givenFirst).
    if ($UpnOrder -eq 'surnameFirst') {
        $UPN = "$NachnameNormalized.$VornameNormalized@$tenantDomain"
    } else {
        $UPN = "$VornameNormalized.$NachnameNormalized@$tenantDomain"
    }
    
    # Generiere DisplayName: "Nachname Vorname"
    $DisplayName = "$Nachname $Vorname"

    Write-Host "Verarbeite Benutzer: $DisplayName ($UPN)"

    $PasswordProfile = @{
        'Password' = $Password
        'ForceChangePasswordNextSignIn' = $ForceChange
    }

    # Prüfe ob Benutzer existiert
    $existingUser = $null
    try {
        $existingUser = Get-MgUser -UserId $UPN -ErrorAction SilentlyContinue
    } catch {
        # Benutzer existiert nicht
    }

    if ($null -eq $existingUser) {
        # Benutzer erstellen
        Write-Host "Benutzer existiert nicht, wird erstellt..." -ForegroundColor Yellow
        
        # MailNickname ist der Teil vor dem @ im UPN
        $mailNickname = $UPN.Split('@')[0]
        
        $newUserParams = @{
            'UserPrincipalName' = $UPN
            'DisplayName' = $DisplayName
            'GivenName' = $Vorname
            'Surname' = $Nachname
            'MailNickname' = $mailNickname
            'PasswordProfile' = $PasswordProfile
            'AccountEnabled' = $true
        }
        
        if (-not [string]::IsNullOrWhiteSpace($Abteilung)) {
            $newUserParams['Department'] = $Abteilung
        }
        if (-not [string]::IsNullOrWhiteSpace($OfficeLocation)) {
            $newUserParams['OfficeLocation'] = $OfficeLocation
        }

        try {
            $newUser = New-MgUser @newUserParams
            if ($null -ne $newUser) {
                Write-Host "Benutzer erfolgreich erstellt: $UPN" -ForegroundColor Green

                # UsageLocation muss gesetzt sein bevor Lizenzen zugewiesen werden können
                # Verwende Österreich als Standard (AT)
                try {
                    Update-MgUser -UserId $UPN -UsageLocation "AT"
                } catch {
                    Write-Host "Warnung: UsageLocation konnte nicht gesetzt werden, versuche trotzdem Lizenz zuzuweisen..." -ForegroundColor Yellow
                }

                # Kurze Pause, damit der Benutzer vollständig im System erstellt wird
                Start-Sleep -Seconds 2

                # Lizenz zuweisen (SKU aus der UI-Auswahl)
                if ($null -ne $licenseSkuId) {
                    try {
                        # Versuche zuerst Set-MgUserLicense (falls verfügbar)
                        if (Get-Command Set-MgUserLicense -ErrorAction SilentlyContinue) {
                            Set-MgUserLicense -UserId $UPN -AddLicenses @(@{SkuId = $licenseSkuId}) -RemoveLicenses @()
                            Write-Host "Lizenz zugewiesen: $licenseSkuId" -ForegroundColor Green
                        } else {
                            # Fallback: Direkte REST API
                            $body = @{
                                addLicenses = @(
                                    @{
                                        skuId = $licenseSkuId
                                    }
                                )
                                removeLicenses = @()
                            }
                            $jsonBody = $body | ConvertTo-Json -Depth 10
                            
                            $uri = "https://graph.microsoft.com/v1.0/users/$($newUser.Id)/assignLicense"
                            $response = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $jsonBody -ContentType "application/json" -ErrorAction Stop
                            Write-Host "Lizenz zugewiesen: $licenseSkuId" -ForegroundColor Green
                        }
                    } catch {
                        $errorMessage = $_.Exception.Message
                        # Versuche detaillierte Fehlermeldung aus Response zu extrahieren
                        if ($_.ErrorDetails) {
                            try {
                                $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json
                                if ($errorDetails.error) {
                                    $errorMessage = "$($errorDetails.error.message) (Code: $($errorDetails.error.code))"
                                }
                            } catch {}
                        }
                        # Falls ErrorDetails nicht verfügbar, versuche aus Exception zu extrahieren
                        if ($_.Exception.Response) {
                            try {
                                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                                $responseBody = $reader.ReadToEnd()
                                $errorObj = $responseBody | ConvertFrom-Json
                                if ($errorObj.error.message) {
                                    $errorMessage = "$($errorObj.error.message) (Code: $($errorObj.error.code))"
                                }
                            } catch {}
                        }
                        Write-Host "FEHLER bei Lizenzzuweisung für ${UPN}: $errorMessage" -ForegroundColor Red
                        Write-Host "SKU ID: $licenseSkuId" -ForegroundColor Yellow
                        Write-Host "###USER_FAIL###$UPN###$errorMessage"
                        $failedUsers += $UPN
                        continue
                    }
                } else {
                    Write-Host "Keine Lizenz zugewiesen (keine ausgewaehlt)." -ForegroundColor Yellow
                }
            } else {
                Write-Host "FEHLER: Benutzer konnte nicht erstellt werden (keine Antwort von API)" -ForegroundColor Red
                Write-Host "###USER_FAIL###$UPN###Benutzer konnte nicht erstellt werden"
                $failedUsers += $UPN
                continue
            }
        } catch {
            $msg = $_.Exception.Message
            Write-Host "FEHLER beim Erstellen des Benutzers ${UPN}: $msg" -ForegroundColor Red
            Write-Host "###USER_FAIL###$UPN###$msg"
            $failedUsers += $UPN
            continue
        }
    } else {
        Write-Host "FEHLER: Benutzer existiert bereits: $UPN" -ForegroundColor Red
        Write-Host "###USER_FAIL###$UPN###Benutzer existiert bereits"
        $failedUsers += $UPN
        continue
    }
}

if ($failedUsers.Count -gt 0) {
    Write-Host "FEHLER: $($failedUsers.Count) Benutzer fehlgeschlagen" -ForegroundColor Red
    exit 1
}
