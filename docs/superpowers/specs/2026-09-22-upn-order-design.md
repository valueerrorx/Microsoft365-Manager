# UPN name order (vorname.nachname vs nachname.vorname)

**Status:** approved (chat 2026-09-22)  
**Default:** `givenFirst` → `vorname.nachname@domain`  
**Scope:** global preference shared by Create Users, Remove Users, Remove Devices; persisted across restarts

## Problem

UPN local-part is hardcoded as `nachname.vorname@domain` in create (PowerShell), UI preview, and remove/match helpers. Tenants that use `vorname.nachname` cannot switch without code changes.

## Goals

- User can choose **Vorname.Nachname** or **Nachname.Vorname** via radio controls in the relevant views.
- Changing the order in one view updates all other views immediately (same Pinia state).
- Preference survives app restart (`localStorage`).
- Default is **Vorname.Nachname** (`givenFirst`).
- Create, preview, and remove/device matching all use the same order.

## Non-goals

- Per-row / per-CSV order overrides.
- Changing DisplayName order (stays `Nachname Vorname`).
- Migrating existing Entra accounts.
- New test framework beyond a tiny Node assert script for pure UPN helpers (repo has no unit-test runner today).

## Architecture

### Shared state

New Pinia store `src/stores/upnOrderStore.js`:

- `order`: `'givenFirst' | 'surnameFirst'`
- Default: `'givenFirst'`
- `setOrder(order)` writes state + `localStorage` key `ms365.upnOrder`
- On store init: read `localStorage`; invalid/missing → `'givenFirst'`
- Do **not** clear this store on logout/session reset (user preference, not tenant session data)

### Pure helpers

Extend `src/utils/upn.js`:

- `UPN_ORDER_GIVEN_FIRST = 'givenFirst'`
- `UPN_ORDER_SURNAME_FIRST = 'surnameFirst'`
- `buildUpn(vorname, nachname, domain, order = UPN_ORDER_GIVEN_FIRST)`  
  - `givenFirst` → `vn.nn@domain`  
  - `surnameFirst` → `nn.vn@domain`
- `resolveUpnForEntry(..., order)` uses the same local-part rule
- Keep `normalizeForUPN` unchanged; keep main-process `normalizeForUPN` in `index.js` in sync for name parts only

Main process does **not** need a duplicate order helper if create passes `upnOrder` into PowerShell and the renderer always builds previews via `upn.js`.

### Create path (authoritative write)

1. UI / `usersStore.runBulkCreate` / single-user create pass current `upnOrder` into IPC.
2. `ipcMain.handle('run-password-update')` accepts `{ upnOrder }` (or reads from a small main-side cache set via `set-csv-data` / dedicated arg). Preferred: pass explicitly on `run-password-update` and spawn PS with `-UpnOrder givenFirst|surnameFirst`.
3. `scripts/update-user-passwords.ps1`:  
   `$UPN = if ($UpnOrder -eq 'surnameFirst') { "$NachnameNormalized.$VornameNormalized@$tenantDomain" } else { "$VornameNormalized.$NachnameNormalized@$tenantDomain" }`  
   Invalid/empty → treat as `givenFirst` (matches app default).
4. `MailNickname` remains local-part before `@`.

`set-csv-data` continues to normalize Vor-/Nachname only; it does not bake order into those columns.

### UI

Reusable inline radio group (small component or shared markup) placed **left of** the primary action button:

| View | Placement |
|------|-----------|
| `CreateUsersView.vue` CSV tab | Left of „Benutzer erstellen / aktualisieren“ |
| `CreateUsersView.vue` single tab | Left of „Benutzer erstellen“ |
| `RemoveUsersView.vue` | Left of „N Benutzer löschen“ (toolbar row) |
| `RemoveDevicesView.vue` (name CSV mode) | Left of „N Geräte entfernen“; hide or disable when pure device-name mode (no UPN build) |

Labels (monospace-friendly):

- `vorname.nachname@…` → value `givenFirst`
- `nachname.vorname@…` → value `surnameFirst`

Vorschau / match tables must react immediately when `order` changes (computed from store).

### Copy / help text

Update short notes that currently say UPN is always `nachname.vorname@…` (Remove Users / Remove Devices help) to mention the selectable order.

## Data flow

```
localStorage ms365.upnOrder
        ↕
upnOrderStore.order  ←────── radios in Create / Remove Users / Remove Devices
        │
        ├─► buildUpn / resolveUpnForEntry / CreateUsersView preview
        └─► runBulkCreate → IPC run-password-update({ upnOrder }) → update-user-passwords.ps1 -UpnOrder
```

## Error handling

- Unknown stored value → default `givenFirst`
- Unknown PS `-UpnOrder` → `givenFirst`
- Missing domain → empty UPN preview (unchanged behavior)

## Testing / verification

1. Fresh install / cleared storage: default preview = `max.mustermann@domain`
2. Switch to `surnameFirst`: preview + create local-part = `mustermann.max@…`
3. Switch on Create → open Remove Users: same selection; match against existing users uses new order
4. Restart app: selection restored
5. Device remove (name CSV): owner UPN uses store order; device-name-only mode unaffected
6. Single-user create uses same order as CSV bulk

## Open decisions (locked)

| Topic | Decision |
|-------|----------|
| Default | `givenFirst` |
| Persistence | `localStorage` |
| Sharing | One global store |
| DisplayName | unchanged |
| Device-name CSV mode | no UPN radios needed |
