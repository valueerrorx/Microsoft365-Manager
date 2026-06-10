# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

# Beispiel fuer ein Intune-Plattform-Script: laeuft via Intune Management Extension
# als SYSTEM auf dem Client. Legt lokalen Admin 'ezadmin' an oder setzt nur das
# Passwort, falls der Benutzer schon vorhanden ist (idempotent).

$ErrorActionPreference = 'Stop'
$user = 'ezadmin'
$pwPlain = 'test'
$pw = ConvertTo-SecureString $pwPlain -AsPlainText -Force

$existing = Get-LocalUser -Name $user -ErrorAction SilentlyContinue
if ($existing) {
    Set-LocalUser -Name $user -Password $pw -PasswordNeverExpires $true
} else {
    New-LocalUser -Name $user -Password $pw -PasswordNeverExpires -AccountNeverExpires `
        -FullName 'EZ Admin' -Description 'Lokaler Admin (Intune)'
}

# Zur lokalen Administratoren-Gruppe (SID S-1-5-32-544, sprachneutral) hinzufuegen
$adminGroup = (Get-LocalGroup -SID 'S-1-5-32-544').Name
if (-not (Get-LocalGroupMember -Group $adminGroup -Member $user -ErrorAction SilentlyContinue)) {
    Add-LocalGroupMember -Group $adminGroup -Member $user
}

Write-Output "ezadmin bereit (Admin)."
