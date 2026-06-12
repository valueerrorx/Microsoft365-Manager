# MS365 Manager

Electron-App zur Verwaltung von Microsoft-365-/Entra-ID-**Benutzern**, **Gruppen**, **Geräten** und **Administratorenrollen** über die Microsoft Graph API (PowerShell + Vue-Oberfläche).

![App UI](./ui.png)

## Features

### Übersicht & Verbindung
- **Dashboard** (`/`): Kennzahlen (Benutzer, Lizenzen, Gruppen, Geräte), Schnellzugriff, Links zu Admin-Portalen
- Graph-Anmeldung per Browser/WAM; **Abmelden** in der Sidebar
- Live-**Logs** + **Graph-PowerShell-Konsole** unten in der App
- **Stoppen laufender Aktionen**: Während eine Aktion läuft (Erstellen, Bulk, Backup/Restore, Geräte-/Rollen-Batch) bricht der **Stoppen**-Button den PowerShell-Lauf hart ab (killt alle App-eigenen `pwsh`-Prozessbäume); bereits ausgeführte Änderungen bleiben bestehen, die App läuft normal weiter

### Benutzer (`/users`)
- Suche, **Mehrfach-Filter** (Lizenz, Abteilung u. a.) mit optionalem **Invertieren** (NICHT-Filter), Sortierung
- Einzelaktionen: Bearbeiten, Passwort, MFA zurücksetzen, aktivieren/deaktivieren, Lizenzen, löschen
- **Mehrfachauswahl**: 2FA zurücksetzen, zur Gruppe hinzufügen, aktivieren/deaktivieren, löschen

### Gruppen (`/groups`)
- Suche, Typ-Filter, Sortierung; Bearbeiten, Mitglieder/Besitzer, löschen (einzeln + **Bulk**)
- **Ablaufrichtlinien** (Lifecycle): anlegen, zuordnen (auch mehrere M365-Gruppen)
- **Intune-Plattform-Script** an Gruppe deployen (Ausführungsstatus abrufbar)

### Geräte (`/devices`)
- Suche (Name/Besitzer/OS), **Mehrfach-Filter** (Verknüpfung, Aktivierung, Konformität, **Besitzer-Lizenz**) mit optionalem **Invertieren** (NICHT-Filter), sortierbare Spalten, Pagination
- Intune: **Retire** (einzeln/Bulk), **Remote Wipe**; reine Entra-Geräte: **löschen**
- **BitLocker-Wiederherstellungsschlüssel** anzeigen (Schlüssel-Icon)
- **Windows LAPS**: lokales Admin-Passwort aus Entra anzeigen (Schild-Icon) — nur Passwörter, die **LAPS nach Entra** gesichert hat (aktuell + Historie, kopierbar); kein generisches Auslesen des lokalen Admin-PWs ohne LAPS

### Rollen (`/roles`)
- Whitelist in `config/managed-directory-roles.json`
- Mitglieder hinzufügen/entfernen; **temporäre Zuweisung** (2–48 h, Auto-Entfernung)

### Aktionen
- **Erstellen / Import** (`/create`): Einzelbenutzer oder CSV — nur **neue** Konten; A3 Schüler/Lehrer-Lizenz bei Erkennung
- **Batch / CSV** (`/remove`): Benutzer per CSV abgleichen und Bulk-Aktionen ausführen — **löschen**, **zu Gruppe hinzufügen**, **Abteilung setzen** (jeweils ein Graph-`$batch`-Lauf; bereits korrekte Abteilungen werden übersprungen). **Lazy-Matching** für abweichende Schreibweisen (Doppelnamen in Vor-/Familienname) mit Vorschlag + Bestätigung pro Zeile; Filter (gefunden/fuzzy/nicht gefunden) und sortierbare Status-Spalte
- **Geräte entfernen / CSV** (`/remove-devices`): alle Geräte eines Besitzers (Retire + Entra-Delete); ebenfalls mit **Lazy-Matching**, Kategorie-Filter und sortierbarer Geräte-Spalte
- **Gruppe erstellen** (`/create-group`): Sicherheits- oder M365-Gruppe
- **Backup** (`/backup`): Benutzer, Gruppen, Rollen und optional **Intune-Richtlinien** als JSON sichern/wiederherstellen
  - **Intune-Richtlinien**: Settings Catalog (`configurationPolicies`) + **Compliance** (`deviceCompliancePolicies`) inkl. Zuweisungen (Gruppe per `mailNickname`, `allDevices`, `allLicensedUsers`)
  - **Nicht** enthalten: Apps, Win32/LOB-Pakete, Legacy-`deviceConfigurations`
  - Restore: fehlende Richtlinien anlegen + zuweisen; bestehende (gleicher Name) werden übersprungen — **Gruppen zuerst** wiederherstellen
  - Backups mit Intune nutzen **Schema v2**; ältere Backups (nur Benutzer/Gruppen/Rollen) bleiben Schema v1

## Voraussetzungen

- **Node.js** + **npm**
- **PowerShell 7 (`pwsh`)** — unter Linux/macOS Pflicht; Windows empfohlen (Fallback: `powershell.exe` 5.1)
- Microsoft-365-Konto mit delegierten Graph-Scopes (siehe `scripts/Connect-Mg365App.ps1` und `graph-device-auth.mjs`), u. a. `User.ReadWrite.All`, `Directory.ReadWrite.All`, `Group.ReadWrite.All`, `RoleManagement.ReadWrite.Directory`, `DeviceManagementManagedDevices.PrivilegedOperations.All`, `DeviceManagementConfiguration.ReadWrite.All` (Intune-Backup), `BitlockerKey.Read.All`, `DeviceLocalCredential.Read.All` (LAPS)
- Für **LAPS-Passwort-Abruf** zusätzlich eine passende Entra-Rolle (z. B. **Cloud Device Administrator** oder **Intune Administrator**)
- `Microsoft.Graph.*`-Module werden bei Bedarf automatisch installiert

## Installation

```bash
git clone git@github.com:valueerrorx/Microsoft365-Manager.git
cd Microsoft365-Manager
npm install
npm run dev
```

## CSV-Format (Benutzer anlegen)

Semikolon oder Komma; Beispiel: [`user-list.csv`](./user-list.csv) (liegt auch unter `public/user-list.csv` und wird beim Build nach `dist/` kopiert — in der App unter **Erstellen**, **Batch** und **Geräte entfernen** als **Beispiel-CSV herunterladen** verlinkt, auch in AppImage/DMG/EXE)

```csv
Vorname,Familienname,Abteilung,UserType,NewPassword,ForceChange
Max,Mustermann,2025,Schüler,Passwort123!,1
Anna,Schmidt,2025,Lehrer,Passwort456!,0
```

| Feld | Pflicht | Beschreibung |
|------|---------|--------------|
| Vorname, Familienname | ja | UPN = `familienname.vorname@tenant-domain`, DisplayName = „Familienname Vorname“ |
| Abteilung | nein | z. B. Jahrgang |
| UserType | nein | `Schüler` oder `Lehrer` → A3-Lizenz |
| NewPassword | ja | Initialpasswort |
| ForceChange | nein | `1` = bei nächster Anmeldung ändern |

**Hinweis:** Existiert der UPN bereits → Fehler (kein Update). Bestehende Konten über **Benutzerliste** pflegen.

Für **Batch / Geräte entfernen** (per CSV) reichen `Vorname` + `Familienname`; Zusatzspalten werden ignoriert. Der Spaltenkopf `Nachname` wird weiterhin akzeptiert. Encoding (UTF-8/Latin-1) wird automatisch erkannt, Umlaute und Diakritika (z. B. `ć`, `ž`, `ă`, `ȳ`) werden korrekt in den UPN übersetzt. Jede CSV-View (Erstellen, Batch, Geräte) hält ihre **eigene** importierte Liste, die über Navigation erhalten bleibt. In der Info-Box **Erwartetes CSV-Format** bzw. **CSV-Format** gibt es einen Download-Link zur Beispieldatei.

## Kurzanleitung

1. **Dashboard** → **Verbinden & Laden** (Browser-Anmeldung beim ersten Mal)
2. Daten in den jeweiligen Ansichten verwalten oder unter **Aktionen** Bulk-Workflows starten
3. Logs und optional Graph-PowerShell unten in der Konsole

## Build

```bash
npm run build
```

Ausgabe unter `dist/` (Linux AppImage/deb, Windows portable/MSI, macOS DMG — je nach Build-OS).

## Architektur (kurz)

```
Vue-Renderer → Electron IPC → index.js → scripts/*.ps1 → Microsoft Graph PowerShell SDK
```

Wichtige Pfade: `index.js` (Main), `src/` (UI), `scripts/` (Graph), `config/managed-directory-roles.json`.

## Lizenz

GPL-3.0-or-later — siehe [LICENSE](./LICENSE).
