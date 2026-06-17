<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com> -->

<template>
  <div>
    <div class="page-header d-flex align-items-center justify-content-between flex-wrap gap-2">
      <div>
        <h1 class="page-title">Geräte</h1>
        <p class="page-subtitle">{{ devicesStore.totalDevices }} Geräte ({{ devicesStore.managedDevicesCount }} Intune)</p>
      </div>
      <div class="d-flex gap-2">
        <button class="btn btn-outline-secondary btn-sm" @click="devicesStore.fetchDevices()" :disabled="devicesStore.loading">
          <i class="bi bi-arrow-clockwise me-1" :class="{ spin: devicesStore.loading }"></i>
          Aktualisieren
        </button>
      </div>
    </div>

    <div class="content-card mb-3">
      <div class="content-card-body py-2">
        <div class="devices-filter-bar d-flex flex-nowrap align-items-center gap-2">
          <div class="devices-filter-search flex-shrink-0">
            <div class="input-group input-group-sm">
              <span class="input-group-text"><i class="bi bi-search"></i></span>
              <input v-model="searchQuery" type="text" class="form-control" placeholder="Suchen…" />
              <button v-if="searchQuery" class="btn btn-outline-secondary" type="button" @click="searchQuery = ''">
                <i class="bi bi-x"></i>
              </button>
            </div>
          </div>
          <div class="devices-filter-msf flex-shrink-0">
            <MultiSelectFilter
              v-model="filterTrusts"
              v-model:invert="filterTrustsInvert"
              :options="trustOptions"
              placeholder="Verknüpfung: alle"
            />
          </div>
          <select v-model="filterEnabled" class="form-select form-select-sm flex-shrink-0 devices-filter-select" aria-label="Aktiviert filtern">
            <option value="all">Aktiviert: alle</option>
            <option value="yes">Aktiviert: Ja</option>
            <option value="no">Aktiviert: Nein</option>
          </select>
          <select v-model="filterCompliant" class="form-select form-select-sm flex-shrink-0 devices-filter-select" aria-label="Konformität filtern">
            <option value="all">Konform: alle</option>
            <option value="yes">Konform: Ja</option>
            <option value="no">Konform: Nein</option>
            <option value="unknown">Konform: ?</option>
          </select>
          <div class="devices-filter-msf flex-shrink-0">
            <MultiSelectFilter
              v-model="filterLicenseSkus"
              v-model:invert="filterLicenseInvert"
              :options="licenseFilterOptions"
              placeholder="Lizenz: alle"
              searchable
            />
          </div>
          <div class="devices-filter-msf flex-shrink-0">
            <MultiSelectFilter
              v-model="filterDepts"
              v-model:invert="filterDeptsInvert"
              :options="deptFilterOptions"
              placeholder="Abteilung: alle"
              searchable
            />
          </div>
          <button
            type="button"
            class="btn btn-outline-secondary btn-sm flex-shrink-0"
            title="Spalten ein-/ausblenden"
            @click="columnsModal.show = true"
          >
            <i class="bi bi-list-ul"></i>
          </button>
          <span class="devices-filter-count flex-shrink-0">{{ filteredDevices.length }} Treffer</span>
        </div>
      </div>
    </div>

    <div
      v-if="!devicesStore.loading && devicesStore.devices.length && selectedDeviceIds.length >= 2"
      class="content-card mb-2"
    >
      <div class="content-card-body py-2 px-3 d-flex flex-wrap align-items-center gap-2">
        <span style="font-size:0.875rem;color:#e6edf3;">
          <strong>{{ selectedDeviceIds.length }}</strong> ausgewählt
        </span>
        <button type="button" class="btn btn-outline-primary btn-sm" :disabled="!selectedIntuneDeviceRows.length" @click="openBulkRetireModal">
          <i class="bi bi-link-45deg me-1"></i>Abkoppeln (Retire)
        </button>
        <button type="button" class="btn btn-outline-primary btn-sm" @click="openAddToGroupModal">
          <i class="bi bi-people me-1"></i>Zu Gruppe hinzufügen
        </button>
        <button
          type="button"
          class="btn btn-outline-primary btn-sm"
          :disabled="!selectedDeviceOwnerUpns.length"
          :title="selectedDeviceOwnerUpns.length ? 'Besitzer-UPNs kopieren' : 'Keine Besitzer-UPN in der Auswahl'"
          @click="copyBatchUpns"
        >
          <i class="bi bi-envelope me-1"></i>UPN kopieren
        </button>
        <button type="button" class="btn btn-link btn-sm text-secondary ms-auto p-0" @click="clearDeviceSelection">
          Auswahl aufheben
        </button>
      </div>
    </div>

    <div v-if="devicesStore.loading" class="text-center py-5">
      <div class="spinner-border" style="color:#58a6ff;" role="status"></div>
      <div style="color:#8b949e;margin-top:1rem;font-size:0.875rem;">Geräte werden geladen…</div>
    </div>

    <div v-else-if="!devicesStore.devices.length" class="text-center py-5">
      <i class="bi bi-pc-display" style="font-size:3rem;color:#30363d;"></i>
      <div style="color:#8b949e;margin-top:1rem;">Noch keine Geräte geladen</div>
      <button class="btn btn-primary btn-sm mt-3" @click="devicesStore.fetchDevices()">
        <i class="bi bi-plug me-1"></i> Geräte laden
      </button>
    </div>

    <div v-else class="content-card" style="position:relative;">
      <div class="table-ms365-hscroll">
        <table class="table table-ms365">
          <thead>
            <tr>
              <th class="text-center" style="width:36px;">
                <input
                  type="checkbox"
                  class="form-check-input"
                  :checked="allFilteredDevicesSelected"
                  :indeterminate.prop="filteredDevicesSelectionIndeterminate"
                  title="Alle in der Liste auswählen"
                  @change="toggleSelectAll"
                />
              </th>
              <th @click="setSort('displayName')" style="cursor:pointer;user-select:none;min-width:9rem;">
                Gerätename <i class="bi" :class="sortIcon('displayName')"></i>
              </th>
              <th v-if="isColVisible('accountEnabled')" @click="setSort('accountEnabled')" style="cursor:pointer;user-select:none;white-space:nowrap;">
                Aktiviert <i class="bi" :class="sortIcon('accountEnabled')"></i>
              </th>
              <th v-if="isColVisible('operatingSystem')" @click="setSort('operatingSystem')" style="cursor:pointer;user-select:none;">
                OS <i class="bi" :class="sortIcon('operatingSystem')"></i>
              </th>
              <th v-if="isColVisible('operatingSystemVersion')" @click="setSort('operatingSystemVersion')" style="cursor:pointer;user-select:none;white-space:nowrap;">
                Version <i class="bi" :class="sortIcon('operatingSystemVersion')"></i>
              </th>
              <th v-if="isColVisible('trustTypeLabel')" @click="setSort('trustTypeLabel')" style="cursor:pointer;user-select:none;min-width:10rem;">
                Verknüpfung <i class="bi" :class="sortIcon('trustTypeLabel')"></i>
              </th>
              <th v-if="isColVisible('ownerDisplayName')" @click="setSort('ownerDisplayName')" style="cursor:pointer;user-select:none;min-width:9rem;">
                Besitzer <i class="bi" :class="sortIcon('ownerDisplayName')"></i>
              </th>
              <th v-if="isColVisible('ownerDepartment')" @click="setSort('ownerDepartment')" style="cursor:pointer;user-select:none;white-space:nowrap;">
                Abteilung <i class="bi" :class="sortIcon('ownerDepartment')"></i>
              </th>
              <th v-if="isColVisible('ownerLicenses')" @click="setSort('ownerLicenses')" style="cursor:pointer;user-select:none;white-space:nowrap;">
                Lizenz <i class="bi" :class="sortIcon('ownerLicenses')"></i>
              </th>
              <th v-if="isColVisible('managementLabel')" @click="setSort('managementLabel')" style="cursor:pointer;user-select:none;">
                MDM <i class="bi" :class="sortIcon('managementLabel')"></i>
              </th>
              <th v-if="isColVisible('securityManagementLabel')" @click="setSort('securityManagementLabel')" style="cursor:pointer;user-select:none;min-width:8rem;">
                Sicherheit <i class="bi" :class="sortIcon('securityManagementLabel')"></i>
              </th>
              <th v-if="isColVisible('isCompliant')" @click="setSort('isCompliant')" style="cursor:pointer;user-select:none;white-space:nowrap;">
                Konform <i class="bi" :class="sortIcon('isCompliant')"></i>
              </th>
              <th v-if="isColVisible('createdDateTime')" @click="setSort('createdDateTime')" style="cursor:pointer;user-select:none;white-space:nowrap;">
                Registriert <i class="bi" :class="sortIcon('createdDateTime')"></i>
              </th>
              <th v-if="isColVisible('approximateLastSignInDateTime')" @click="setSort('approximateLastSignInDateTime')" style="cursor:pointer;user-select:none;white-space:nowrap;">
                Aktivität <i class="bi" :class="sortIcon('approximateLastSignInDateTime')"></i>
              </th>
              <th style="width:200px;">Aktionen</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="d in paginatedDevices" :key="d.id">
              <td class="text-center align-middle">
                <input
                  type="checkbox"
                  class="form-check-input"
                  :checked="isDeviceRowSelected(d.id)"
                  @change="toggleDeviceRowSelected(d.id)"
                />
              </td>
              <td>
                <div style="font-weight:500;">{{ d.displayName || '—' }}</div>
              </td>
              <td v-if="isColVisible('accountEnabled')">
                <span v-if="d.accountEnabled" class="badge-active">Ja</span>
                <span v-else class="badge-inactive">Nein</span>
              </td>
              <td v-if="isColVisible('operatingSystem')" style="font-size:0.82rem;">{{ d.operatingSystem || '—' }}</td>
              <td v-if="isColVisible('operatingSystemVersion')" style="font-size:0.82rem;font-family:monospace;color:#8b949e;">{{ d.operatingSystemVersion || '—' }}</td>
              <td v-if="isColVisible('trustTypeLabel')">
                <span v-if="d.trustType === 'AzureAd'" class="badge-license">{{ d.trustTypeLabel || d.trustType }}</span>
                <span v-else-if="d.trustType === 'Workplace'" class="badge-entra-registered">{{ d.trustTypeLabel || d.trustType }}</span>
                <span v-else style="font-size:0.82rem;">{{ d.trustTypeLabel || d.trustType || '—' }}</span>
              </td>
              <td v-if="isColVisible('ownerDisplayName')">
                <div style="font-size:0.82rem;">{{ ownerName(d) }}</div>
                <div v-if="d.ownerUserPrincipalName" style="font-size:0.72rem;color:#8b949e;font-family:monospace;">{{ d.ownerUserPrincipalName }}</div>
              </td>
              <td v-if="isColVisible('ownerDepartment')" style="font-size:0.82rem;">{{ ownerDepartment(d) || '—' }}</td>
              <td v-if="isColVisible('ownerLicenses')">
                <div v-if="ownerLicenses(d).length" class="d-flex flex-wrap gap-1">
                  <span v-for="label in ownerLicenses(d).slice(0, 2)" :key="label" class="badge-license" style="font-size:0.72rem;">{{ label }}</span>
                  <span v-if="ownerLicenses(d).length > 2" class="badge-license" style="font-size:0.72rem;">+{{ ownerLicenses(d).length - 2 }}</span>
                </div>
                <span v-else style="font-size:0.8rem;color:#484f58;">—</span>
              </td>
              <td v-if="isColVisible('managementLabel')">
                <span v-if="d.managementLabel" class="badge-mdm">{{ d.managementLabel }}</span>
                <span v-else style="font-size:0.8rem;color:#484f58;">—</span>
              </td>
              <td v-if="isColVisible('securityManagementLabel')" style="font-size:0.8rem;">{{ d.securityManagementLabel || '—' }}</td>
              <td v-if="isColVisible('isCompliant')">
                <span v-if="d.isCompliant === true" class="badge-active">Ja</span>
                <span v-else-if="d.isCompliant === false" class="badge-inactive">Nein</span>
                <span v-else style="color:#484f58;font-size:0.78rem;">—</span>
              </td>
              <td v-if="isColVisible('createdDateTime')" style="font-size:0.82rem;color:#8b949e;white-space:nowrap;" :title="d.createdDateTime || ''">{{ formatDeviceDateTime(d.createdDateTime) }}</td>
              <td v-if="isColVisible('approximateLastSignInDateTime')" style="font-size:0.82rem;color:#8b949e;white-space:nowrap;" :title="d.approximateLastSignInDateTime || ''">{{ formatDeviceDateTime(d.approximateLastSignInDateTime) }}</td>
              <td>
                <div class="d-flex gap-1 flex-wrap">
                  <button
                    type="button"
                    class="btn-action"
                    title="BitLocker-Wiederherstellungsschlüssel anzeigen"
                    @click="openBitlockerModal(d)"
                  >
                    <i class="bi bi-key"></i>
                  </button>
                  <button
                    type="button"
                    class="btn-action"
                    title="LAPS lokales Admin-Passwort anzeigen"
                    @click="openLapsModal(d)"
                  >
                    <i class="bi bi-shield-lock"></i>
                  </button>
                  <button
                    type="button"
                    class="btn-action"
                    :title="d.isIntuneManaged ? 'Abkoppeln (Intune Retire)' : 'Nur für in Intune eingeschriebene Geräte'"
                    :disabled="!d.isIntuneManaged"
                    @click="openRetireModal(d)"
                  >
                    <i class="bi bi-link-45deg"></i>
                  </button>
                  <button
                    type="button"
                    class="btn-action danger"
                    :title="d.isIntuneManaged ? 'Werkseinstellungen (Remote Wipe)' : 'Nur für in Intune eingeschriebene Geräte'"
                    :disabled="!d.isIntuneManaged"
                    @click="openWipeModal(d)"
                  >
                    <i class="bi bi-arrow-counterclockwise"></i>
                  </button>
                  <button
                    v-if="!d.isIntuneManaged"
                    type="button"
                    class="btn-action danger"
                    title="Aus Entra entfernen (Verzeichnis-Eintrag löschen)"
                    @click="openDeleteEntraModal(d)"
                  >
                    <i class="bi bi-trash"></i>
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        v-if="filteredDevices.length"
        class="d-flex align-items-center justify-content-between flex-wrap gap-2 p-3"
        style="border-top:1px solid var(--sidebar-border);"
      >
        <span style="font-size:0.8rem;color:#8b949e;">Seite {{ currentPage }} von {{ totalPages }}</span>
        <div class="d-flex align-items-center gap-2 flex-wrap">
          <div class="d-flex align-items-center gap-1">
            <span style="font-size:0.8rem;color:#8b949e;">Pro Seite</span>
            <select v-model.number="pageSize" class="form-select form-select-sm" style="width:auto;min-width:4.25rem;">
              <option v-for="n in pageSizeOptions" :key="n" :value="n">{{ n }}</option>
            </select>
          </div>
          <div v-if="totalPages > 1" class="d-flex gap-2">
            <button type="button" class="btn btn-outline-secondary btn-sm" :disabled="currentPage <= 1" @click="currentPage--">
              <i class="bi bi-chevron-left"></i>
            </button>
            <button type="button" class="btn btn-outline-secondary btn-sm" :disabled="currentPage >= totalPages" @click="currentPage++">
              <i class="bi bi-chevron-right"></i>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Column picker -->
    <div v-if="columnsModal.show" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,0.6);">
      <div class="modal-dialog modal-sm">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              <i class="bi bi-list-ul me-2" style="color:#58a6ff;"></i>Spalten
            </h5>
            <button type="button" class="btn-close" @click="columnsModal.show = false"></button>
          </div>
          <div class="modal-body py-2">
            <label
              v-for="col in DEVICE_TABLE_COLUMNS"
              :key="col.key"
              class="d-flex align-items-center gap-2 py-1 mb-0"
              style="font-size:0.85rem;cursor:pointer;"
            >
              <input
                type="checkbox"
                class="form-check-input mt-0"
                :checked="isColVisible(col.key)"
                :disabled="col.required"
                @change="setColVisible(col.key, $event.target.checked)"
              />
              <span :style="{ color: col.required ? '#8b949e' : '#e6edf3' }">{{ col.label }}</span>
            </label>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-outline-secondary btn-sm" @click="resetVisibleColumns">Standard</button>
            <button type="button" class="btn btn-primary btn-sm" @click="columnsModal.show = false">Fertig</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Batch Retire -->
    <div v-if="bulkRetireModal.show" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,0.6);">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              <i class="bi bi-link-45deg me-2" style="color:#58a6ff;"></i>{{ bulkRetireModal.count }} Geräte abkoppeln (Retire)
            </h5>
            <button type="button" class="btn-close" :disabled="bulkRetireModal.running" @click="bulkRetireModal.show = false"></button>
          </div>
          <div class="modal-body">
            <p class="small mb-2">
              Intune entfernt die Verwaltung von allen ausgewählten Geräten nacheinander. Geräte ohne Intune-Einschreibung werden übersprungen.
            </p>
            <p class="small mb-3" style="color:#f85149;">
              <strong>Wirklich ausführen?</strong> Nur bei bewusster Offboarding-Entscheidung.
            </p>
            <div class="form-check">
              <input id="bulkRetireDisableUser" v-model="bulkRetireModal.disableUserAccount" class="form-check-input" type="checkbox" :disabled="bulkRetireModal.running" />
              <label class="form-check-label small" for="bulkRetireDisableUser">
                Schulbenutzerkonten in Microsoft Entra <strong>deaktivieren</strong> (je Gerät, wenn UPN ermittelbar)
              </label>
            </div>
            <p v-if="bulkRetireModal.disableUserAccount" class="small mt-2 mb-0" style="color:#8b949e;">
              Betroffene Benutzer können sich danach <strong>nicht mehr</strong> mit diesem Konto anmelden (pro Gerät separat).
            </p>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary btn-sm" @click="bulkRetireModal.running ? cancelRunningPs() : (bulkRetireModal.show = false)">{{ bulkRetireModal.running ? 'Stoppen' : 'Abbrechen' }}</button>
            <button type="button" class="btn btn-primary btn-sm" :disabled="bulkRetireModal.running" @click="runBulkRetire">
              {{ bulkRetireModal.running ? 'Wird ausgeführt…' : 'Alle abkoppeln' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Retire (Intune abkoppeln) -->
    <div v-if="retireModal.show" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,0.6);">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title"><i class="bi bi-link-45deg me-2" style="color:#58a6ff;"></i>Gerät abkoppeln (Retire)</h5>
            <button type="button" class="btn-close" :disabled="retireModal.running" @click="retireModal.show = false"></button>
          </div>
          <div class="modal-body">
            <p class="small mb-2">
              Intune entfernt die Verwaltung von diesem Gerät (Schulprofile/Apps je nach Plattform). Das Gerät selbst wird dabei nicht automatisch auf Werkseinstellungen zurückgesetzt.
            </p>
            <p class="small mb-3" style="color:#f85149;">
              <strong>Wirklich ausführen?</strong> Nur bei bewusster Offboarding-Entscheidung.
            </p>
            <div class="form-check">
              <input id="retireDisableUser" v-model="retireModal.disableUserAccount" class="form-check-input" type="checkbox" :disabled="retireModal.running" />
              <label class="form-check-label small" for="retireDisableUser">
                Schulbenutzerkonto in Microsoft Entra <strong>deaktivieren</strong>
              </label>
            </div>
            <p v-if="retireModal.disableUserAccount" class="small mt-2 mb-0" style="color:#8b949e;">
              Der Benutzer kann sich danach <strong>nicht mehr</strong> mit diesem Konto am Gerät und bei Microsoft-365-Diensten anmelden (sofern kein anderes Konto genutzt wird).
            </p>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary btn-sm" @click="retireModal.running ? cancelRunningPs() : (retireModal.show = false)">{{ retireModal.running ? 'Stoppen' : 'Abbrechen' }}</button>
            <button type="button" class="btn btn-primary btn-sm" :disabled="retireModal.running" @click="runRetire">
              {{ retireModal.running ? 'Wird ausgeführt…' : 'Abkoppeln' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Delete Entra device (non-Intune) -->
    <div v-if="deleteEntraModal.show" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,0.6);">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title text-danger"><i class="bi bi-trash me-2"></i>Aus Entra entfernen</h5>
            <button type="button" class="btn-close" :disabled="deleteEntraModal.running" @click="closeDeleteEntraModal"></button>
          </div>
          <div class="modal-body">
            <div class="alert" style="background:rgba(248,81,73,0.1);border:1px solid rgba(248,81,73,0.25);color:#f85149;border-radius:6px;">
              <i class="bi bi-exclamation-triangle-fill me-2"></i>
              <strong>Achtung:</strong> Der Entra-Verzeichnis-Eintrag wird endgültig gelöscht. Das physische Gerät wird dabei nicht zurückgesetzt.
            </div>
            <p class="small mb-2" style="color:#8b949e;">
              Gerät: <strong style="color:#e6edf3;">{{ deleteEntraModal.device?.displayName || deleteEntraModal.device?.id }}</strong>
            </p>
            <label class="form-label small">{{ deleteEntraConfirmLabel }}</label>
            <input v-model="deleteEntraModal.confirmName" type="text" class="form-control" :disabled="deleteEntraModal.running" autocomplete="off" />
            <div v-if="deleteEntraModal.error" class="mt-2" style="color:#f85149;font-size:0.83rem;">
              <i class="bi bi-exclamation-triangle me-1"></i>{{ deleteEntraModal.error }}
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary btn-sm" @click="deleteEntraModal.running ? cancelRunningPs() : closeDeleteEntraModal()">{{ deleteEntraModal.running ? 'Stoppen' : 'Abbrechen' }}</button>
            <button
              type="button"
              class="btn btn-danger btn-sm"
              :disabled="deleteEntraModal.running || deleteEntraModal.confirmName !== deleteEntraConfirmExpected"
              @click="runDeleteEntra"
            >
              {{ deleteEntraModal.running ? 'Löscht…' : 'Endgültig löschen' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Factory reset (Remote Wipe) -->
    <div v-if="wipeModal.show" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,0.6);">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title text-danger"><i class="bi bi-arrow-counterclockwise me-2"></i>Werkseinstellungen (Remote Wipe)</h5>
            <button type="button" class="btn-close" :disabled="wipeModal.running" @click="wipeModal.show = false"></button>
          </div>
          <div class="modal-body">
            <p class="small">
              Es wird ein <strong>Remote-Wipe</strong> ausgelöst: Das Gerät setzt Daten je nach Plattform und Richtlinie zurück, sobald es online ist (effektiv Factory-Reset / Datenlöschung).
            </p>
            <p class="small text-danger mb-2"><strong>Nur bei Schulgeräten oder klarer Freigabe verwenden.</strong></p>
            <label class="form-label small">{{ wipeConfirmLabel }}</label>
            <input v-model="wipeModal.confirmName" type="text" class="form-control" :disabled="wipeModal.running" autocomplete="off" />
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary btn-sm" @click="wipeModal.running ? cancelRunningPs() : (wipeModal.show = false)">{{ wipeModal.running ? 'Stoppen' : 'Abbrechen' }}</button>
            <button
              type="button"
              class="btn btn-danger btn-sm"
              :disabled="wipeModal.running || wipeModal.confirmName !== wipeConfirmExpected"
              @click="runWipe"
            >
              {{ wipeModal.running ? 'Wipe wird ausgelöst…' : 'Wipe auslösen' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- LAPS Local Admin Password -->
    <div v-if="lapsModal.show" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,0.6);">
      <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              <i class="bi bi-shield-lock me-2" style="color:#58a6ff;"></i>
              LAPS Admin: {{ lapsModal.device?.displayName || lapsModal.deviceName || lapsModal.device?.id }}
            </h5>
            <button type="button" class="btn-close" @click="lapsModal.show = false"></button>
          </div>
          <div class="modal-body">
            <div v-if="lapsModal.loading" class="text-center py-4 text-secondary small">
              <div class="spinner-border spinner-border-sm me-2" style="color:#58a6ff;"></div>
              Passwort wird geladen…
            </div>
            <div v-else-if="lapsModal.error" class="alert alert-danger small mb-0">{{ lapsModal.error }}</div>
            <div v-else-if="!lapsModal.credentials.length" class="py-3 text-center small text-secondary">
              {{ lapsModal.emptyMessage || 'Kein LAPS-Passwort in Entra für dieses Gerät gespeichert.' }}
            </div>
            <div v-else>
              <div v-if="lapsModal.lastBackupDateTime" class="small text-secondary mb-2">
                Letztes Backup: {{ formatDeviceDateTime(lapsModal.lastBackupDateTime) }}
              </div>
              <div
                v-for="(c, idx) in lapsModal.credentials"
                :key="`${c.accountName}-${c.backupDateTime}-${idx}`"
                class="mb-2 p-2 rounded"
                style="background:rgba(0,0,0,0.2);border:1px solid #30363d;"
              >
                <div class="d-flex justify-content-between align-items-center mb-1">
                  <span class="small text-secondary">
                    {{ c.accountName || 'Administrator' }}
                    <span v-if="c.isCurrent" class="badge rounded-pill ms-1" style="background:#238636;color:#fff;font-size:0.65rem;">Aktuell</span>
                    <span v-else class="ms-1">· {{ formatDeviceDateTime(c.backupDateTime) }}</span>
                  </span>
                  <button type="button" class="btn btn-link btn-sm p-0" title="Passwort kopieren" @click="copyKey(c.password)">
                    <i class="bi bi-clipboard"></i>
                  </button>
                </div>
                <code style="font-size:0.85rem;color:#e6edf3;word-break:break-all;">{{ c.password || '— (Wert nicht abrufbar)' }}</code>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary btn-sm" @click="lapsModal.show = false">Schließen</button>
          </div>
        </div>
      </div>
    </div>

    <!-- BitLocker Recovery Keys -->
    <div v-if="bitlockerModal.show" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,0.6);">
      <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              <i class="bi bi-key me-2" style="color:#58a6ff;"></i>
              BitLocker-Schlüssel: {{ bitlockerModal.device?.displayName || bitlockerModal.device?.id }}
            </h5>
            <button type="button" class="btn-close" @click="bitlockerModal.show = false"></button>
          </div>
          <div class="modal-body">
            <div v-if="bitlockerModal.loading" class="text-center py-4 text-secondary small">
              <div class="spinner-border spinner-border-sm me-2" style="color:#58a6ff;"></div>
              Schlüssel werden geladen…
            </div>
            <div v-else-if="bitlockerModal.error" class="alert alert-danger small mb-0">{{ bitlockerModal.error }}</div>
            <div v-else-if="!bitlockerModal.keys.length" class="py-3 text-center small text-secondary">
              Keine BitLocker-Wiederherstellungsschlüssel für dieses Gerät gefunden.
            </div>
            <div v-else>
              <div
                v-for="k in bitlockerModal.keys"
                :key="k.id"
                class="mb-2 p-2 rounded"
                style="background:rgba(0,0,0,0.2);border:1px solid #30363d;"
              >
                <div class="d-flex justify-content-between align-items-center mb-1">
                  <span class="small text-secondary">
                    {{ k.volumeType || 'Volume' }} · {{ formatDeviceDateTime(k.createdDateTime) }}
                  </span>
                  <button type="button" class="btn btn-link btn-sm p-0" title="Schlüssel kopieren" @click="copyKey(k.key)">
                    <i class="bi bi-clipboard"></i>
                  </button>
                </div>
                <code style="font-size:0.85rem;color:#e6edf3;word-break:break-all;">{{ k.key || '— (Wert nicht abrufbar)' }}</code>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary btn-sm" @click="bitlockerModal.show = false">Schließen</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Zu Gruppe hinzufügen (Geräte) -->
    <div v-if="groupPickerModal.show" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,0.6);">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              <i class="bi bi-people me-2" style="color:#58a6ff;"></i>
              Geräte zur Gruppe hinzufügen
            </h5>
            <button type="button" class="btn-close" :disabled="groupPickerModal.running" @click="closeGroupPickerModal"></button>
          </div>
          <div class="modal-body">
            <p class="small mb-2" style="color:#8b949e;">
              <strong style="color:#e6edf3;">{{ groupPickerModal.deviceCount }}</strong> Geräte werden der gewählten Gruppe zugeordnet.
              Bereits vorhandene Mitglieder werden übersprungen. Dynamische Gruppen sind nicht wählbar.
            </p>
            <div class="input-group input-group-sm mb-2">
              <span class="input-group-text"><i class="bi bi-search"></i></span>
              <input
                v-model="groupSearchQuery"
                type="text"
                class="form-control"
                placeholder="Gruppe suchen (Name, E-Mail-Alias)..."
                :disabled="groupsStore.loading || groupPickerModal.running"
              />
            </div>
            <div v-if="groupsStore.loading" class="text-center py-4" style="color:#8b949e;">
              <div class="spinner-border spinner-border-sm me-2" style="color:#58a6ff;"></div>
              Gruppen werden geladen...
            </div>
            <div v-else-if="!filteredDirectoryGroups.length" class="py-3 text-center small" style="color:#8b949e;">
              Keine Gruppen passend zum Filter.
            </div>
            <div v-else class="group-picker-list">
              <label
                v-for="g in filteredDirectoryGroups"
                :key="g.id"
                class="d-flex align-items-start gap-2 py-2 px-2 group-picker-row"
                :class="{ 'group-picker-row-active': groupPickerModal.selectedGroupId === g.id }"
              >
                <input
                  v-model="groupPickerModal.selectedGroupId"
                  type="radio"
                  class="form-check-input mt-1"
                  :value="g.id"
                  :disabled="groupPickerModal.running"
                />
                <span class="flex-grow-1" style="min-width:0;">
                  <span class="d-block fw-medium" style="color:#e6edf3;">{{ g.displayName || g.id }}</span>
                  <span v-if="g.mailNickname" class="d-block font-monospace small" style="color:#8b949e;">{{ g.mailNickname }}</span>
                  <span class="badge rounded-pill me-1 mt-1" style="font-size:0.65rem;background:#30363d;color:#8b949e;">{{ groupKindLabel(g) }}</span>
                </span>
              </label>
            </div>
          </div>
          <div class="modal-footer flex-wrap gap-2">
            <span v-if="groupPickerModal.selectedGroupId" class="me-auto small" style="color:#8b949e;">
              Gewählt: <strong style="color:#e6edf3;">{{ selectedGroupDisplayName }}</strong>
            </span>
            <button type="button" class="btn btn-secondary btn-sm" @click="groupPickerModal.running ? cancelRunningPs() : closeGroupPickerModal()">{{ groupPickerModal.running ? 'Stoppen' : 'Abbrechen' }}</button>
            <button
              type="button"
              class="btn btn-primary btn-sm"
              :disabled="groupPickerModal.running || !groupPickerModal.selectedGroupId || groupsStore.loading"
              @click="runAddDevicesToGroup"
            >
              {{ groupPickerModal.running ? 'Wird ausgeführt...' : 'Hinzufügen' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, reactive, watch, onMounted } from 'vue'
import { useDevicesStore } from '../stores/devicesStore'
import { useUsersStore } from '../stores/usersStore'
import { useGroupsStore } from '../stores/groupsStore'
import { useAuthStore } from '../stores/authStore'
import { humanLicenseLabel, licenseListSortRank } from '../utils/licenseLabel.js'
import MultiSelectFilter, { MSF_NONE } from '../components/MultiSelectFilter.vue'
import { cancelRunningPs, resetPsCancel } from '../utils/cancelPs'
import { copyUpnsToClipboard } from '../utils/copyUpns.js'

const devicesStore = useDevicesStore()
const usersStore = useUsersStore()
const groupsStore = useGroupsStore()
const authStore = useAuthStore()

// Statische (nicht-dynamische) Gruppen aus dem geteilten groupsStore — dynamische erlauben kein manuelles Hinzufügen
const assignableGroups = computed(() => groupsStore.groups.filter((g) => !g.isDynamic))

// Toggleable table columns (checkbox + Aktionen always visible).
const DEVICE_TABLE_COLUMNS = [
  { key: 'displayName', label: 'Gerätename', required: true },
  { key: 'accountEnabled', label: 'Aktiviert', defaultVisible: false },
  { key: 'operatingSystem', label: 'OS' },
  { key: 'operatingSystemVersion', label: 'Version', defaultVisible: false },
  { key: 'trustTypeLabel', label: 'Verknüpfung' },
  { key: 'ownerDisplayName', label: 'Besitzer' },
  { key: 'ownerDepartment', label: 'Abteilung' },
  { key: 'ownerLicenses', label: 'Lizenz', defaultVisible: false },
  { key: 'managementLabel', label: 'MDM' },
  { key: 'securityManagementLabel', label: 'Sicherheit' },
  { key: 'isCompliant', label: 'Konform' },
  { key: 'createdDateTime', label: 'Registriert', defaultVisible: false },
  { key: 'approximateLastSignInDateTime', label: 'Aktivität' }
]
const DEFAULT_VISIBLE_COLUMNS = DEVICE_TABLE_COLUMNS
  .filter((c) => c.defaultVisible !== false)
  .map((c) => c.key)
const visibleColumnKeys = ref([...DEFAULT_VISIBLE_COLUMNS])
const columnsModal = reactive({ show: false })

function isColVisible(key) {
  return visibleColumnKeys.value.includes(key)
}

function setColVisible(key, on) {
  const col = DEVICE_TABLE_COLUMNS.find((c) => c.key === key)
  if (col?.required) return
  if (on) {
    if (!visibleColumnKeys.value.includes(key)) visibleColumnKeys.value = [...visibleColumnKeys.value, key]
  } else {
    visibleColumnKeys.value = visibleColumnKeys.value.filter((k) => k !== key)
  }
}

function resetVisibleColumns() {
  visibleColumnKeys.value = [...DEFAULT_VISIBLE_COLUMNS]
}

const retireModal = reactive({ show: false, device: null, disableUserAccount: false, running: false })
const bulkRetireModal = reactive({ show: false, disableUserAccount: false, running: false, count: 0 })
const wipeModal = reactive({ show: false, device: null, confirmName: '', running: false })
const deleteEntraModal = reactive({ show: false, device: null, confirmName: '', running: false, error: '' })
const bitlockerModal = reactive({ show: false, device: null, loading: false, keys: [], error: '' })
const lapsModal = reactive({ show: false, device: null, deviceName: '', loading: false, credentials: [], lastBackupDateTime: '', emptyMessage: '', error: '' })

const selectedDeviceIds = ref([])

const selectedIntuneDeviceRows = computed(() =>
  selectedDeviceIds.value
    .map((id) => devicesStore.devices.find((d) => d.id === id))
    .filter((d) => d?.isIntuneManaged)
)

// Unique owner UPNs from the current device selection (for batch copy).
const selectedDeviceOwnerUpns = computed(() => {
  const seen = new Set()
  const out = []
  for (const id of selectedDeviceIds.value) {
    const upn = String(devicesStore.devices.find((d) => d.id === id)?.ownerUserPrincipalName || '').trim()
    const key = upn.toLowerCase()
    if (!upn || seen.has(key)) continue
    seen.add(key)
    out.push(upn)
  }
  return out
})

const searchQuery = ref('')
const filterTrusts = ref([])
const filterTrustsInvert = ref(false)
const filterEnabled = ref('all')
const filterCompliant = ref('all')
const filterLicenseSkus = ref([]) // skuIds des Gerätebesitzers + 'none' (kein/unlizenzierter Besitzer)
const filterLicenseInvert = ref(false)
const filterDepts = ref([])
const filterDeptsInvert = ref(false)

// Feste Verknüpfungstyp-Optionen ('other' = sonstige/leer).
const trustOptions = [
  { value: 'AzureAd', label: 'Entra gejoint' },
  { value: 'Workplace', label: 'Entra registriert' },
  { value: 'ServerAd', label: 'Hybrid' },
  { value: 'other', label: 'Sonstige / leer' }
]

// UPN (lowercase) -> User-Objekt (für Besitzer-Lizenz und -Name)
const userByUpn = computed(() => {
  const map = {}
  for (const u of usersStore.users) {
    const upn = String(u.userPrincipalName || '').toLowerCase()
    if (upn) map[upn] = u
  }
  return map
})

// UPN (lowercase) -> Set der zugewiesenen skuIds des Besitzers
const ownerSkuMap = computed(() => {
  const map = {}
  for (const [upn, u] of Object.entries(userByUpn.value)) {
    map[upn] = new Set((u.assignedLicenses || []).map((l) => l.skuId))
  }
  return map
})

// Besitzername = "Nachname Vorname" aus dem User-Objekt; Fallback auf den Geräte-Besitzer-Anzeigenamen
function ownerUser(d) {
  const upn = String(d.ownerUserPrincipalName || '').toLowerCase()
  return upn ? userByUpn.value[upn] : null
}

function ownerName(d) {
  const u = ownerUser(d)
  const parts = [u?.surname, u?.givenName].filter(Boolean)
  return parts.length ? parts.join(' ') : (d.ownerDisplayName || '—')
}

function ownerDepartment(d) {
  return ownerUser(d)?.department || ''
}

function licenseLabel(skuId) {
  const sku = usersStore.licenseMap[skuId]
  if (!sku) return skuId?.slice(0, 8) || '?'
  return humanLicenseLabel(sku.skuPartNumber)
}

function ownerLicenses(d) {
  return (ownerUser(d)?.assignedLicenses || []).map((l) => licenseLabel(l.skuId))
}

function ownerLicenseSortText(d) {
  return ownerLicenses(d).join(', ')
}

// Lizenz-Filteroptionen: nur SKUs die bei mind. einem Gerätebesitzer vorkommen
const ownerLicenseOptions = computed(() => {
  const seen = new Set()
  for (const skus of Object.values(ownerSkuMap.value)) {
    for (const id of skus) seen.add(id)
  }
  return [...seen]
    .map((id) => ({ skuId: id, sku: usersStore.licenseMap[id]?.skuPartNumber, label: humanLicenseLabel(usersStore.licenseMap[id]?.skuPartNumber) || id }))
    .sort((a, b) => {
      const r = licenseListSortRank(a.sku) - licenseListSortRank(b.sku)
      return r !== 0 ? r : a.label.localeCompare(b.label)
    })
})
// Optionen für MultiSelectFilter: 'none' (kein/unlizenzierter Besitzer) + alle vorkommenden SKUs.
const licenseFilterOptions = computed(() => [
  { value: 'none', label: 'Ohne Lizenz / kein Besitzer' },
  ...ownerLicenseOptions.value.map((o) => ({ value: o.skuId, label: o.label }))
])
// Abteilungs-Filteroptionen: nur Abteilungen die bei Gerätebesitzern vorkommen.
const deptFilterOptions = computed(() => {
  const depts = new Set()
  let hasNone = false
  for (const d of devicesStore.devices) {
    const upn = String(d.ownerUserPrincipalName || '').toLowerCase()
    const u = upn ? userByUpn.value[upn] : null
    if (!u) { hasNone = true; continue }
    if (u.department) depts.add(u.department)
    else hasNone = true
  }
  const opts = [...depts].sort().map((dep) => ({ value: dep, label: dep }))
  if (hasNone) opts.push({ value: '__none__', label: '(ohne Abteilung)' })
  return opts
})
const sortKey = ref('displayName')
const sortDir = ref(1)
const currentPage = ref(1)
const pageSizeOptions = [50, 100, 200, 400, 800]
const pageSize = ref(50)

const filteredDevices = computed(() => {
  let list = devicesStore.devices
  const q = searchQuery.value.trim().toLowerCase()
  if (q) {
    list = list.filter(
      (d) =>
        (d.displayName || '').toLowerCase().includes(q) ||
        ownerName(d).toLowerCase().includes(q) ||
        (d.ownerDisplayName || '').toLowerCase().includes(q) ||
        (d.ownerUserPrincipalName || '').toLowerCase().includes(q) ||
        (d.operatingSystem || '').toLowerCase().includes(q) ||
        (d.operatingSystemVersion || '').toLowerCase().includes(q) ||
        (d.trustTypeLabel || '').toLowerCase().includes(q) ||
        (d.managementLabel || '').toLowerCase().includes(q) ||
        ownerDepartment(d).toLowerCase().includes(q) ||
        ownerLicenseSortText(d).toLowerCase().includes(q)
    )
  }
  if (filterTrusts.value.includes(MSF_NONE)) { if (!filterTrustsInvert.value) list = [] }
  else if (filterTrusts.value.length) {
    const want = new Set(filterTrusts.value)
    list = list.filter((d) => {
      const t = d.trustType || ''
      const isOther = !t || !['AzureAd', 'Workplace', 'ServerAd'].includes(t)
      const match = want.has(t) || (isOther && want.has('other'))
      return filterTrustsInvert.value ? !match : match
    })
  }
  const fe = filterEnabled.value
  if (fe === 'yes') list = list.filter((d) => d.accountEnabled === true)
  if (fe === 'no') list = list.filter((d) => d.accountEnabled === false)
  const fc = filterCompliant.value
  if (fc === 'yes') list = list.filter((d) => d.isCompliant === true)
  if (fc === 'no') list = list.filter((d) => d.isCompliant === false)
  if (fc === 'unknown') list = list.filter((d) => d.isCompliant !== true && d.isCompliant !== false)
  if (filterLicenseSkus.value.includes(MSF_NONE)) { if (!filterLicenseInvert.value) list = [] }
  else if (filterLicenseSkus.value.length) {
    const want = new Set(filterLicenseSkus.value)
    const wantNone = want.has('none')
    list = list.filter((d) => {
      const upn = String(d.ownerUserPrincipalName || '').toLowerCase()
      const skus = upn ? ownerSkuMap.value[upn] : null
      const noneMatch = wantNone && (!skus || skus.size === 0)
      const skuMatch = !!skus && [...skus].some((id) => want.has(id))
      const match = noneMatch || skuMatch
      return filterLicenseInvert.value ? !match : match
    })
  }
  if (filterDepts.value.includes(MSF_NONE)) { if (!filterDeptsInvert.value) list = [] }
  else if (filterDepts.value.length) {
    const want = new Set(filterDepts.value)
    const wantNone = want.has('__none__')
    list = list.filter((d) => {
      const upn = String(d.ownerUserPrincipalName || '').toLowerCase()
      const u = upn ? userByUpn.value[upn] : null
      const dept = u?.department || ''
      const match = (wantNone && !dept) || (dept && want.has(dept))
      return filterDeptsInvert.value ? !match : match
    })
  }

  return [...list].sort((a, b) => {
    const key = sortKey.value
    if (key === 'accountEnabled' || key === 'isCompliant') {
      const av = boolSortKey(a[key])
      const bv = boolSortKey(b[key])
      return av < bv ? -sortDir.value : av > bv ? sortDir.value : 0
    }
    if (key === 'createdDateTime' || key === 'approximateLastSignInDateTime') {
      const av = dateSortKey(a[key])
      const bv = dateSortKey(b[key])
      return av < bv ? -sortDir.value : av > bv ? sortDir.value : 0
    }
    const av = (
      key === 'ownerDisplayName' ? ownerName(a)
      : key === 'ownerDepartment' ? ownerDepartment(a)
      : key === 'ownerLicenses' ? ownerLicenseSortText(a)
      : (a[key] || '')
    ).toLowerCase()
    const bv = (
      key === 'ownerDisplayName' ? ownerName(b)
      : key === 'ownerDepartment' ? ownerDepartment(b)
      : key === 'ownerLicenses' ? ownerLicenseSortText(b)
      : (b[key] || '')
    ).toLowerCase()
    return av < bv ? -sortDir.value : av > bv ? sortDir.value : 0
  })
})

const totalPages = computed(() => {
  const len = filteredDevices.value.length
  if (!len) return 1
  return Math.ceil(len / pageSize.value)
})

const paginatedDevices = computed(() => {
  const ps = pageSize.value
  const start = (currentPage.value - 1) * ps
  return filteredDevices.value.slice(start, start + ps)
})

const allFilteredDevicesSelected = computed(() => {
  const list = filteredDevices.value
  return list.length > 0 && list.every((d) => d.id && selectedDeviceIds.value.includes(d.id))
})

const filteredDevicesSelectionIndeterminate = computed(() => {
  const list = filteredDevices.value.filter((d) => d.id)
  if (!list.length) return false
  const n = list.filter((d) => selectedDeviceIds.value.includes(d.id)).length
  return n > 0 && n < list.length
})

function isDeviceRowSelected(id) {
  return selectedDeviceIds.value.includes(id)
}

function toggleDeviceRowSelected(id) {
  if (selectedDeviceIds.value.includes(id)) {
    selectedDeviceIds.value = selectedDeviceIds.value.filter((x) => x !== id)
  } else {
    selectedDeviceIds.value = [...selectedDeviceIds.value, id]
  }
}

// Toggle selection for all filtered devices (not just the current page).
function toggleSelectAll() {
  if (allFilteredDevicesSelected.value) {
    clearDeviceSelection()
  } else {
    selectedDeviceIds.value = filteredDevices.value.map((d) => d.id).filter(Boolean)
  }
}

function clearDeviceSelection() {
  selectedDeviceIds.value = []
}

function openBulkRetireModal() {
  bulkRetireModal.count = selectedIntuneDeviceRows.value.length
  bulkRetireModal.disableUserAccount = false
  bulkRetireModal.show = true
}

async function runBulkRetire() {
  const rows = selectedIntuneDeviceRows.value
  if (!rows.length) {
    bulkRetireModal.show = false
    return
  }
  resetPsCancel()
  bulkRetireModal.running = true
  await devicesStore.retireIntuneDevicesBatch(rows, bulkRetireModal.disableUserAccount)
  bulkRetireModal.running = false
  bulkRetireModal.show = false
  clearDeviceSelection()
}

watch([() => filteredDevices.value.length, pageSize], () => {
  const len = filteredDevices.value.length
  if (!len) return
  const tp = Math.ceil(len / pageSize.value)
  if (currentPage.value > tp) currentPage.value = tp
})

watch(pageSize, () => {
  currentPage.value = 1
})

watch(searchQuery, () => {
  currentPage.value = 1
})

watch([filterTrusts, filterTrustsInvert, filterEnabled, filterCompliant, filterLicenseSkus, filterLicenseInvert, filterDepts, filterDeptsInvert], () => {
  currentPage.value = 1
})

function setSort(key) {
  if (sortKey.value === key) sortDir.value *= -1
  else {
    sortKey.value = key
    sortDir.value = 1
  }
  currentPage.value = 1
}

function sortIcon(key) {
  if (sortKey.value !== key) return 'bi-chevron-expand text-secondary'
  return sortDir.value === 1 ? 'bi-chevron-up' : 'bi-chevron-down'
}

function dateSortKey(iso) {
  if (!iso) return 0
  const t = new Date(iso).getTime()
  return Number.isNaN(t) ? 0 : t
}

function boolSortKey(v) {
  if (v === true) return 2
  if (v === false) return 1
  return 0
}

function formatDeviceDateTime(iso) {
  if (!iso) return '—'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString('de-DE', { dateStyle: 'short', timeStyle: 'short' })
}

function deviceConfirmTarget(d) {
  const n = (d?.displayName || '').trim()
  return n || (d?.id || '').trim()
}

function wipeConfirmTarget(d) {
  return deviceConfirmTarget(d)
}

const wipeConfirmExpected = computed(() => wipeConfirmTarget(wipeModal.device))

const wipeConfirmLabel = computed(() => {
  const d = wipeModal.device
  if (!d) return 'Bestätigung'
  return (d.displayName || '').trim() ? 'Gerätename zur Bestätigung eintippen' : 'Geräte-ID zur Bestätigung eintippen'
})

const deleteEntraConfirmExpected = computed(() => deviceConfirmTarget(deleteEntraModal.device))

const deleteEntraConfirmLabel = computed(() => {
  const d = deleteEntraModal.device
  if (!d) return 'Bestätigung'
  return (d.displayName || '').trim() ? 'Gerätename zur Bestätigung eintippen' : 'Geräte-ID zur Bestätigung eintippen'
})

function openDeleteEntraModal(d) {
  if (d?.isIntuneManaged) return
  deleteEntraModal.device = d
  deleteEntraModal.confirmName = ''
  deleteEntraModal.error = ''
  deleteEntraModal.running = false
  deleteEntraModal.show = true
}

function closeDeleteEntraModal() {
  if (deleteEntraModal.running) return
  deleteEntraModal.show = false
}

async function runDeleteEntra() {
  const d = deleteEntraModal.device
  if (!d?.id || deleteEntraModal.confirmName !== deleteEntraConfirmExpected.value) {
    deleteEntraModal.error = 'Bestätigung stimmt nicht überein.'
    return
  }
  deleteEntraModal.running = true
  deleteEntraModal.error = ''
  const ok = await devicesStore.deleteEntraDevice(d.id)
  deleteEntraModal.running = false
  if (ok) deleteEntraModal.show = false
  else deleteEntraModal.error = 'Gerät konnte nicht gelöscht werden. Prüfe das Ausgabefenster.'
}

function openRetireModal(d) {
  retireModal.device = d
  retireModal.disableUserAccount = false
  retireModal.show = true
}

async function runRetire() {
  const d = retireModal.device
  if (!d?.id) return
  retireModal.running = true
  const ok = await devicesStore.retireIntuneDevice({
    azureAdDeviceId: d.deviceId || d.id,
    intuneManagedDeviceId: d.intuneManagedDeviceId,
    disableUserAccount: retireModal.disableUserAccount,
    userUpn: d.ownerUserPrincipalName || ''
  })
  retireModal.running = false
  if (ok) retireModal.show = false
}

function openWipeModal(d) {
  wipeModal.device = d
  wipeModal.confirmName = ''
  wipeModal.show = true
}

async function openBitlockerModal(d) {
  bitlockerModal.device = d
  bitlockerModal.keys = []
  bitlockerModal.error = ''
  bitlockerModal.show = true
  // Recovery keys werden über die Entra deviceId (azureADDeviceId) gefiltert
  const azureAdDeviceId = d.deviceId
  if (!azureAdDeviceId) {
    bitlockerModal.error = 'Keine Entra deviceId für dieses Gerät verfügbar.'
    return
  }
  bitlockerModal.loading = true
  const res = await devicesStore.fetchBitlockerKeys(azureAdDeviceId)
  bitlockerModal.loading = false
  if (res.status === 'ok') {
    bitlockerModal.keys = res.keys || []
  } else {
    bitlockerModal.error = res.message || 'Schlüssel konnten nicht geladen werden.'
  }
}

async function openLapsModal(d) {
  lapsModal.device = d
  lapsModal.deviceName = ''
  lapsModal.credentials = []
  lapsModal.lastBackupDateTime = ''
  lapsModal.emptyMessage = ''
  lapsModal.error = ''
  lapsModal.show = true
  const azureAdDeviceId = d.deviceId
  if (!azureAdDeviceId) {
    lapsModal.error = 'Keine Entra deviceId für dieses Gerät verfügbar.'
    return
  }
  lapsModal.loading = true
  const res = await devicesStore.fetchLapsCredentials(azureAdDeviceId)
  lapsModal.loading = false
  if (res.status === 'ok') {
    lapsModal.deviceName = res.deviceName || ''
    lapsModal.lastBackupDateTime = res.lastBackupDateTime || ''
    lapsModal.credentials = res.credentials || []
    lapsModal.emptyMessage = res.message || ''
  } else {
    lapsModal.error = res.message || 'LAPS-Passwort konnte nicht geladen werden.'
  }
}

function copyKey(key) {
  if (key) navigator.clipboard?.writeText(key)
}

async function runWipe() {
  const d = wipeModal.device
  if (!d?.id || wipeModal.confirmName !== wipeConfirmExpected.value) return
  wipeModal.running = true
  const ok = await devicesStore.wipeIntuneDevice({
    azureAdDeviceId: d.deviceId || d.id,
    intuneManagedDeviceId: d.intuneManagedDeviceId
  })
  wipeModal.running = false
  if (ok) wipeModal.show = false
}

// --- Zu Gruppe hinzufügen (Geräte) ---
const groupPickerModal = reactive({ show: false, running: false, selectedGroupId: '', deviceCount: 0 })
const groupSearchQuery = ref('')

const filteredDirectoryGroups = computed(() => {
  const q = groupSearchQuery.value.trim().toLowerCase()
  const list = assignableGroups.value
  if (!q) return list
  return list.filter(
    (g) =>
      (g.displayName || '').toLowerCase().includes(q) ||
      (g.mailNickname || '').toLowerCase().includes(q)
  )
})

const selectedGroupDisplayName = computed(() => {
  const id = groupPickerModal.selectedGroupId
  if (!id) return ''
  const g = assignableGroups.value.find((x) => x.id === id)
  return g?.displayName || id
})

function groupKindLabel(g) {
  const types = g.groupTypes || []
  if (types.includes('Unified')) return 'Microsoft 365'
  if (g.securityEnabled === true) return 'Security'
  return 'Gruppe'
}

async function openAddToGroupModal() {
  if (selectedDeviceIds.value.length < 2) return
  groupPickerModal.deviceCount = selectedDeviceIds.value.length
  groupPickerModal.selectedGroupId = ''
  groupSearchQuery.value = ''
  groupPickerModal.running = false
  groupPickerModal.show = true
  if (!groupsStore.groups.length && !groupsStore.loading) await groupsStore.fetchGroupsDetail()
}

async function copyBatchUpns() {
  if (selectedDeviceIds.value.length < 2) return
  await copyUpnsToClipboard(selectedDeviceOwnerUpns.value, authStore.showToast.bind(authStore))
}

function closeGroupPickerModal() {
  if (groupPickerModal.running) return
  groupPickerModal.show = false
}

async function runAddDevicesToGroup() {
  if (!groupPickerModal.selectedGroupId) return
  // selectedDeviceIds enthält bereits die Entra-Geräte-Objekt-IDs (d.id)
  const ids = selectedDeviceIds.value.filter(Boolean)
  if (!ids.length) return
  groupPickerModal.running = true
  const { ok } = await devicesStore.addDevicesToGroup({
    groupId: groupPickerModal.selectedGroupId,
    deviceIds: ids
  })
  groupPickerModal.running = false
  if (ok) {
    groupPickerModal.show = false
    clearDeviceSelection()
  }
}

onMounted(() => {
  if (!devicesStore.devices.length && !devicesStore.loading) devicesStore.fetchDevices()
  if (!usersStore.users.length && !usersStore.loading) usersStore.fetchUsers()
})
</script>

<style scoped>
.spin {
  animation: spin 1s linear infinite;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
.group-picker-list {
  max-height: 280px;
  overflow: auto;
  border: 1px solid #30363d;
  border-radius: 6px;
  background: rgba(0, 0, 0, 0.12);
}
.group-picker-row {
  cursor: pointer;
  border-bottom: 1px solid rgba(48, 54, 61, 0.55);
  margin: 0;
}
.group-picker-row:hover {
  background: rgba(88, 166, 255, 0.06);
}
.group-picker-row-active {
  background: rgba(88, 166, 255, 0.12);
}
.devices-filter-bar {
  overflow-x: auto;
  min-width: 0;
}
.devices-filter-search {
  width: 11rem;
}
.devices-filter-msf {
  width: 8.5rem;
}
.devices-filter-bar :deep(.msf) {
  width: 100%;
}
.devices-filter-bar :deep(.msf-toggle) {
  min-width: 0;
  width: 100%;
  max-width: 8.5rem;
}
.devices-filter-select {
  width: auto;
  min-width: 6.75rem;
  max-width: 8.5rem;
  white-space: nowrap;
}
.devices-filter-count {
  margin-left: auto;
  font-size: 0.8rem;
  color: #8b949e;
  white-space: nowrap;
}
</style>
