# Graph Report - Microsoft365-Manager  (2026-06-16)

## Corpus Check
- 81 files · ~76,030 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 785 nodes · 889 edges · 129 communities (105 shown, 24 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 7 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d0e12dbf`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 55|Community 55]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 58|Community 58]]
- [[_COMMUNITY_Community 59|Community 59]]
- [[_COMMUNITY_Community 60|Community 60]]
- [[_COMMUNITY_Community 61|Community 61]]
- [[_COMMUNITY_Community 62|Community 62]]
- [[_COMMUNITY_Community 63|Community 63]]
- [[_COMMUNITY_Community 66|Community 66]]
- [[_COMMUNITY_Community 67|Community 67]]
- [[_COMMUNITY_Community 74|Community 74]]
- [[_COMMUNITY_Community 78|Community 78]]
- [[_COMMUNITY_Community 83|Community 83]]
- [[_COMMUNITY_Community 84|Community 84]]
- [[_COMMUNITY_Community 86|Community 86]]
- [[_COMMUNITY_Community 89|Community 89]]
- [[_COMMUNITY_Community 109|Community 109]]
- [[_COMMUNITY_Community 110|Community 110]]
- [[_COMMUNITY_Community 111|Community 111]]
- [[_COMMUNITY_Community 112|Community 112]]
- [[_COMMUNITY_Community 113|Community 113]]
- [[_COMMUNITY_Community 115|Community 115]]
- [[_COMMUNITY_Community 116|Community 116]]
- [[_COMMUNITY_Community 123|Community 123]]
- [[_COMMUNITY_Community 124|Community 124]]
- [[_COMMUNITY_Community 126|Community 126]]
- [[_COMMUNITY_Community 127|Community 127]]

## God Nodes (most connected - your core abstractions)
1. `performDisconnectMg365()` - 14 edges
2. `MS-365 Benutzer-Verwaltungs Tool` - 13 edges
3. `MS-365 Benutzer-Verwaltungs Tool` - 13 edges
4. `build` - 12 edges
5. `Project: MS-365 User Management Dashboard (Electron + Vue + PowerShell/Graph)` - 12 edges
6. `Project: MS-365 User Management Dashboard (Electron + Vue + PowerShell/Graph)` - 12 edges
7. `useAuthStore` - 11 edges
8. `authDebug()` - 10 edges
9. `runPsScriptBody()` - 10 edges
10. `resetAllDataStores()` - 10 edges

## Surprising Connections (you probably didn't know these)
- `performDisconnectMg365()` --calls--> `resetGraphCredential()`  [INFERRED]
  index.js → graph-device-auth.mjs
- `performDisconnectMg365()` --calls--> `deletePersistedGraphAuth()`  [INFERRED]
  index.js → graph-device-auth.mjs
- `resetAllDataStores()` --calls--> `useUsersStore`  [INFERRED]
  src/stores/sessionReset.js → src/stores/usersStore.js
- `Connect-Mg365App()` --calls--> `Ensure-Mg365GraphModule()`  [INFERRED]
  scripts/Connect-Mg365App.ps1 → scripts/Mg365-GraphModules.ps1
- `resetAllDataStores()` --calls--> `useDevicesStore`  [INFERRED]
  src/stores/sessionReset.js → src/stores/devicesStore.js

## Import Cycles
- 3-file cycle: `src/stores/authStore.js -> src/stores/sessionReset.js -> src/stores/groupsStore.js -> src/stores/authStore.js`
- 3-file cycle: `src/stores/authStore.js -> src/stores/sessionReset.js -> src/stores/rolesStore.js -> src/stores/authStore.js`
- 3-file cycle: `src/stores/authStore.js -> src/stores/sessionReset.js -> src/stores/usersStore.js -> src/stores/authStore.js`
- 3-file cycle: `src/stores/authStore.js -> src/stores/sessionReset.js -> src/stores/devicesStore.js -> src/stores/authStore.js`

## Hyperedges (group relationships)
- **IPC-to-PowerShell Execution Bridge** — indexjs_ipc_getusers, indexjs_runpsscript, ps_getms365users [EXTRACTED 1.00]
- **JSON Sentinel Output Protocol (PS scripts + parser)** — ps_getms365users, ps_resetmfa, ps_updateuser, ps_deleteuser, ps_updateuserlicenses, indexjs_parsejsonfromoutput, indexjs_json_sentinel_protocol [EXTRACTED 1.00]
- **Auth Store Log Aggregation and UI Display Flow** — app_authstore, app_logconsole, app_toastnotifications [EXTRACTED 0.95]
- **Bulk User Creation Flow: CreateUsersView → usersStore.runBulkCreate → IPC → PowerShell** — createusersview_csvtab, usersstore_runbulkcreate, projectmd_ipcchannels [EXTRACTED 0.95]
- **Pinia Store Coordination: usersStore calls authStore for logging and toast notifications on every IPC action** — usersstore_usersstore, authstore_authstore, authstore_logs [EXTRACTED 0.98]
- **License Display Pipeline: usersStore.licenseMap + humanLicenseLabel → UsersView badges & DashboardView bars** — usersstore_getters, licenselabel_humanlicenselabel, dashboardview_licenseoverview [INFERRED 0.88]

## Communities (129 total, 24 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (61): activePsProcesses, ALLOWED_MS_ADMIN_HOSTS, authDebug(), authLogUi(), buildPsScriptEnv(), buildPsSpawnOptions(), checkPwshForDashboard(), clearLegacyGraphPsCacheFiles() (+53 more)

### Community 1 - "Community 1"
Cohesion: 0.48
Nodes (5): Resolve-OwnerLabel(), Try-GroupLabel(), Try-OrgContactLabel(), Try-SpLabel(), Try-UserLabel()

### Community 2 - "Community 2"
Cohesion: 0.32
Nodes (4): createSingleUser(), entryError(), entryUpn(), normalizeForUPN()

### Community 49 - "Community 49"
Cohesion: 0.06
Nodes (39): 1. Verbindung herstellen / Daten laden, 2. Benutzer verwalten (Benutzerliste), 3. Gruppen verwalten, 4. Geräte und Intune-Aktionen, 5. Neue Benutzer anlegen (Einzeln oder CSV), 6. Logs anzeigen, Aktionen, ANSI-Escape-Codes in den Logs (+31 more)

### Community 50 - "Community 50"
Cohesion: 0.11
Nodes (11): authStore, dashboardGroupsLifecycleDisplay, dashboardRefreshing, devicesStore, displayedLicenses, groupsStore, msAdminPortals, pwshWarning (+3 more)

### Community 51 - "Community 51"
Cohesion: 0.05
Nodes (43): build, appId, dmg, files, icon, linux, mac, msi (+35 more)

### Community 52 - "Community 52"
Cohesion: 0.09
Nodes (22): Architektur & Datenfluss, CSV / UPN Normalisierung: wichtige Stelle, Dev/Build/Run, Electron Main Process, JSON-Rückgaben aus PowerShell, Nicht-Ziele / Out-of-scope (aktuell), PowerShell Scripts: Aufgaben & Graph Permissions, Project: MS-365 User Management Dashboard (Electron + Vue + PowerShell/Graph) (+14 more)

### Community 53 - "Community 53"
Cohesion: 0.06
Nodes (33): author, dependencies, @azure/identity, @azure/identity-cache-persistence, bootstrap, bootstrap-icons, pinia, vue (+25 more)

### Community 54 - "Community 54"
Cohesion: 0.12
Nodes (13): strengthColors, strengthLabels, validatePassword(), authStore, createSingleUser(), entryError(), entryUpn(), normalizeForUPN() (+5 more)

### Community 55 - "Community 55"
Cohesion: 0.07
Nodes (29): 1. Verbindung herstellen / Daten laden, 2. Benutzer verwalten (Benutzerliste), 3. Gruppen verwalten, 4. Geräte und Intune-Aktionen, 5. Neue Benutzer anlegen (Einzeln oder CSV), 6. Logs anzeigen, ANSI-Escape-Codes in den Logs, Architektur (+21 more)

### Community 57 - "Community 57"
Cohesion: 0.06
Nodes (36): resetPsCancel(), addTemporary, addUserIds, addUserSearch, authStore, busy, confirmActionEnabled, confirmModal (+28 more)

### Community 58 - "Community 58"
Cohesion: 0.09
Nodes (22): Architektur & Datenfluss, CSV / UPN Normalisierung: wichtige Stelle, Dev/Build/Run, Electron Main Process, JSON-Rückgaben aus PowerShell, Nicht-Ziele / Out-of-scope (aktuell), PowerShell Scripts: Aufgaben & Graph Permissions, Project: MS-365 User Management Dashboard (Electron + Vue + PowerShell/Graph) (+14 more)

### Community 59 - "Community 59"
Cohesion: 0.17
Nodes (10): 0. Compact replies (token budget), 1. Think Before Coding, 2. Simplicity First, 3. Surgical Changes, 4. Goal-Driven Execution, 5. Project memory (`memory.md`), 6. Graphify (repository knowledge graph), Encoding format (keep stable; extend only with necessity) (+2 more)

### Community 60 - "Community 60"
Cohesion: 0.12
Nodes (14): 0. Compact replies (token budget), 1. Think Before Coding, 2. Simplicity First, 3. Surgical Changes, 4. Goal-Driven Execution, 5. Project memory (`memory.md`), 6. Graphify (repository knowledge graph), Arbeitsweise (+6 more)

### Community 61 - "Community 61"
Cohesion: 0.40
Nodes (3): permissions, allow, deny

### Community 62 - "Community 62"
Cohesion: 0.29
Nodes (12): authRecordPath(), buildCredential(), deletePersistedGraphAuth(), getGraphDelegatedToken(), GRAPH_DELEGATED_SCOPES, loadAuthRecord(), registerPersistence(), resetGraphCredential() (+4 more)

### Community 67 - "Community 67"
Cohesion: 0.32
Nodes (10): Connect-Mg365App(), Connect-Mg365InteractiveBrowser(), Ensure-WamConsoleWindow(), Get-Mg365MsalAssemblyPath(), Get-Ms365ParentWindowHandle(), Register-Mg365MsalCache(), Save-Mg365AuthRecord(), Write-Mg365AuthLog() (+2 more)

### Community 74 - "Community 74"
Cohesion: 0.03
Nodes (40): allPageDevicesSelected, bitlockerModal, bulkRetireModal, currentPage, deleteEntraConfirmExpected, deleteEntraConfirmLabel, deleteEntraModal, filterCompliant (+32 more)

### Community 78 - "Community 78"
Cohesion: 0.20
Nodes (5): canLogout, devicesStore, groupsStore, rolesStore, usersStore

### Community 84 - "Community 84"
Cohesion: 0.67
Nodes (4): Get-ActivatedDirectoryRoleByTemplateId(), Get-DirectoryRoleUserMembers(), Get-OrActivateDirectoryRole(), New-DirectoryRoleFromTemplate()

### Community 109 - "Community 109"
Cohesion: 0.12
Nodes (12): useBackupStore, anyRestoreSelected, anySelected, authStore, backupStore, preview, pwValid, rsel (+4 more)

### Community 110 - "Community 110"
Cohesion: 0.18
Nodes (5): routes, autoNickname, form, groupsStore, running

### Community 112 - "Community 112"
Cohesion: 0.60
Nodes (3): Get-GraphAll(), Get-IntuneAssignmentTargets(), Resolve-GroupMailNickname()

### Community 113 - "Community 113"
Cohesion: 0.26
Nodes (7): useAuthStore, useDevicesStore, useGroupsStore, useRolesStore, resetAllDataStores(), cancelRunningPs(), psCancelRequested

### Community 115 - "Community 115"
Cohesion: 0.53
Nodes (4): useUsersStore, a3LicenseBucket(), humanLicenseLabel(), licenseListSortRank()

### Community 116 - "Community 116"
Cohesion: 0.67
Nodes (3): clearDeviceSelection(), runAddDevicesToGroup(), runBulkRetire()

### Community 124 - "Community 124"
Cohesion: 0.12
Nodes (16): allMode, buttonLabel, clearAll(), emit, menu, menuStyle, noneMode, onInvert() (+8 more)

### Community 126 - "Community 126"
Cohesion: 0.05
Nodes (29): buildUpn(), normalizeForUPN(), ambiguousRows, authStore, confirm, deptModal, domain, filteredGroups (+21 more)

## Knowledge Gaps
- **344 isolated node(s):** `allow`, `allow`, `deny`, `GRAPH_DELEGATED_SCOPES`, `__filename` (+339 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **24 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `build` connect `Community 51` to `Community 53`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Why does `useAuthStore` connect `Community 113` to `Community 109`, `Community 50`, `Community 115`, `Community 54`, `Community 57`, `Community 126`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `performDisconnectMg365()` connect `Community 0` to `Community 62`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `performDisconnectMg365()` (e.g. with `deletePersistedGraphAuth()` and `resetGraphCredential()`) actually correct?**
  _`performDisconnectMg365()` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `allow`, `allow`, `deny` to the rest of the system?**
  _344 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.06128364389233954 - nodes in this community are weakly interconnected._
- **Should `Community 49` be split into smaller, more focused modules?**
  _Cohesion score 0.05641025641025641 - nodes in this community are weakly interconnected._