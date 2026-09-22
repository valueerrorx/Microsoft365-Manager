<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com> -->

<template>
  <div>
    <!-- Header -->
    <div class="page-header">
      <h1 class="page-title">Benutzer erstellen / importieren</h1>
      <p class="page-subtitle">Einzelnen Benutzer anlegen oder per CSV-Datei massenimportieren</p>
    </div>

    <!-- Tabs -->
    <ul class="nav nav-tabs mb-0">
      <li class="nav-item">
        <button class="nav-link" :class="{ active: tab === 'single' }" @click="tab = 'single'">
          <i class="bi bi-person-plus me-1"></i> Einzelner Benutzer
        </button>
      </li>
      <li class="nav-item">
        <button class="nav-link" :class="{ active: tab === 'csv' }" @click="tab = 'csv'">
          <i class="bi bi-file-earmark-spreadsheet me-1"></i> CSV Import
          <span v-if="usersStore.csvEntries.length" class="ms-1" style="font-size:0.7rem;background:rgba(88,166,255,0.15);color:#58a6ff;border-radius:10px;padding:0.1rem 0.4rem;">
            {{ usersStore.csvEntries.length }}
          </span>
        </button>
      </li>
    </ul>

    <!-- Single User Tab -->
    <div v-if="tab === 'single'" class="content-card" style="border-top-left-radius:0;">
      <div class="content-card-body">
        <div class="row g-3" style="max-width:700px;">
          <div class="col-6">
            <label class="form-label">Vorname <span style="color:#f85149;">*</span></label>
            <input v-model="singleForm.vorname" type="text" class="form-control" placeholder="Max" />
          </div>
          <div class="col-6">
            <label class="form-label">Nachname <span style="color:#f85149;">*</span></label>
            <input v-model="singleForm.nachname" type="text" class="form-control" placeholder="Mustermann" />
          </div>
          <div class="col-6">
            <label class="form-label">Abteilung</label>
            <input v-model="singleForm.abteilung" type="text" class="form-control" placeholder="z.B. 3AHIT" />
          </div>
          <div class="col-6">
            <label class="form-label">Büro</label>
            <input v-model="singleForm.officeLocation" type="text" class="form-control" placeholder="z.B. Raum 101" />
          </div>
          <div class="col-6">
            <label class="form-label">Benutzertyp</label>
            <select v-model="singleForm.userType" class="form-select">
              <option>Schüler</option>
              <option>Lehrer</option>
            </select>
          </div>
          <div class="col-12">
            <label class="form-label">Passwort <span style="color:#f85149;">*</span></label>
            <PasswordInput v-model="singleForm.newPassword" hints-position="side">
              <template #below>
                <div class="form-check">
                  <input class="form-check-input" type="checkbox" v-model="singleForm.forceChange" id="singleForce" />
                  <label class="form-check-label" for="singleForce">PW bei nächster Anmeldung ändern</label>
                </div>
              </template>
            </PasswordInput>
          </div>
          <div class="col-12 d-flex align-items-center gap-3 flex-wrap">
            <UpnOrderRadios name="upn-order-single" />
            <button
              class="btn btn-success"
              @click="createSingleUser"
              :disabled="usersStore.bulkRunning || !singleForm.vorname || !singleForm.nachname || !pwValid"
              :title="!pwValid && singleForm.newPassword ? 'Passwort erfüllt nicht die Komplexitätsanforderungen' : ''"
            >
              <i class="bi" :class="usersStore.bulkRunning ? 'bi-arrow-repeat spin' : 'bi-person-plus'"></i>
              {{ usersStore.bulkRunning ? 'Erstellt...' : 'Benutzer erstellen' }}
            </button>
          </div>
        </div>

        <div v-if="singlePreview.upn" style="max-width:700px;margin-top:1rem;">
          <div style="background:rgba(88,166,255,0.08);border:1px solid rgba(88,166,255,0.2);border-radius:6px;padding:0.6rem 0.875rem;font-size:0.82rem;">
            <span style="color:#8b949e;">UPN Vorschau: </span>
            <span style="font-family:monospace;color:#58a6ff;">{{ singlePreview.upn }}</span>
            <span style="color:#8b949e;margin-left:0.75rem;">Anzeigename: </span>
            <span style="color:#e6edf3;">{{ singlePreview.displayName }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- CSV Import Tab -->
    <div v-if="tab === 'csv'" class="content-card" style="border-top-left-radius:0;border-top-right-radius:0;">
      <div class="content-card-body">
        <!-- Import Area -->
        <div class="d-flex gap-2 mb-4">
          <button class="btn btn-primary" @click="importCsv">
            <i class="bi bi-upload me-1"></i> CSV-Datei importieren
          </button>
          <button v-if="usersStore.csvEntries.length" class="btn btn-outline-secondary" @click="usersStore.csvEntries = []">
            <i class="bi bi-x-circle me-1"></i> Liste leeren
          </button>
        </div>

        <!-- CSV Format Info -->
        <div v-if="!usersStore.csvEntries.length" class="mb-4">
          <div style="background:rgba(88,166,255,0.06);border:1px solid rgba(88,166,255,0.15);border-radius:6px;padding:1rem;">
            <div style="font-size:0.85rem;font-weight:600;margin-bottom:0.5rem;">
              <i class="bi bi-info-circle me-1" style="color:#58a6ff;"></i> Erwartetes CSV-Format
            </div>
            <pre style="font-family:monospace;font-size:0.78rem;color:#8b949e;margin:0;white-space:pre-wrap;">Vorname;Familienname;Abteilung;UserType;NewPassword;ForceChange
Max;Mustermann;3AHIT;Schüler;Passwort123!;1
Anna;Schmidt;LehrerInnenzimmer;Lehrer;Passwort456!;0</pre>
            <div style="font-size:0.78rem;color:#8b949e;margin-top:0.5rem;">
              Trennzeichen: Semikolon oder Komma. Encoding: UTF-8 oder Windows-1252 (Excel).
            </div>
            <a href="#" @click.prevent="downloadSampleCsv(sampleCsvUrl, 'user-list.csv')" style="display:inline-block;font-size:0.78rem;margin-top:0.5rem;color:#58a6ff;">
              <i class="bi bi-download me-1"></i> Beispiel-CSV herunterladen
            </a>
          </div>
        </div>

        <!-- CSV Preview Table -->
        <div v-if="usersStore.csvEntries.length">
          <div class="d-flex align-items-center justify-content-between mb-2 flex-wrap gap-2">
            <span style="font-size:0.875rem;font-weight:600;">{{ usersStore.csvEntries.length }} Einträge bereit</span>
            <div class="d-flex align-items-center gap-3 flex-wrap">
              <UpnOrderRadios name="upn-order-csv" />
              <button v-if="usersStore.bulkRunning" class="btn btn-outline-danger" @click="cancelRunningPs">
                <i class="bi bi-stop-fill"></i> Stoppen
              </button>
              <button class="btn btn-success" @click="openBulkConfirm" :disabled="usersStore.bulkRunning">
                <i class="bi" :class="usersStore.bulkRunning ? 'bi-arrow-repeat spin' : 'bi-play-fill'"></i>
                {{ usersStore.bulkRunning ? 'Läuft...' : 'Benutzer erstellen / aktualisieren' }}
              </button>
            </div>
          </div>

          <div class="table-ms365-hscroll table-ms365-hscroll--y">
            <table class="table table-ms365 csv-preview-table">
              <thead>
                <tr>
                  <th style="width:28px;"></th>
                  <th>#</th>
                  <th>Vorname</th>
                  <th>Nachname</th>
                  <th>UPN Vorschau</th>
                  <th>Abteilung</th>
                  <th>Typ</th>
                  <th>Passwort</th>
                  <th>PW ändern</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(entry, i) in usersStore.csvEntries" :key="i" :class="{ 'row-has-error': entryError(entry) }">
                  <td class="text-center">
                    <i
                      v-if="entryError(entry)"
                      class="bi bi-exclamation-triangle-fill"
                      style="color:#f85149;"
                      :title="entryError(entry)"
                    ></i>
                  </td>
                  <td style="color:#8b949e;">{{ i + 1 }}</td>
                  <td><input v-model="entry.vorname" type="text" class="form-control form-control-sm" /></td>
                  <td><input v-model="entry.nachname" type="text" class="form-control form-control-sm" /></td>
                  <td style="font-family:monospace;font-size:0.72rem;color:#8b949e;">{{ entryLocalPart(entry) }}</td>
                  <td><input v-model="entry.abteilung" type="text" class="form-control form-control-sm" /></td>
                  <td>
                    <select v-model="entry.userType" class="form-select form-select-sm">
                      <option>Schüler</option>
                      <option>Lehrer</option>
                    </select>
                  </td>
                  <td><input v-model="entry.newPassword" type="text" class="form-control form-control-sm" /></td>
                  <td class="text-center">
                    <input type="checkbox" class="form-check-input" style="width:16px !important;height:16px !important;min-width:16px;display:inline-block;flex:none;float:none;" v-model="entry.forceChange" />
                  </td>
                  <td>
                    <button class="btn-action danger" @click="usersStore.csvEntries.splice(i, 1)">
                      <i class="bi bi-trash"></i>
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <!-- Add Row -->
          <button class="btn btn-outline-secondary btn-sm mt-2" @click="addEmptyRow">
            <i class="bi bi-plus me-1"></i> Zeile hinzufügen
          </button>
        </div>

        <!-- Failed Users -->
        <div v-if="usersStore.failedUsers.length" class="mt-3">
          <div style="background:rgba(248,81,73,0.1);border:1px solid rgba(248,81,73,0.25);border-radius:6px;padding:0.75rem;">
            <div style="font-size:0.875rem;font-weight:600;color:#f85149;margin-bottom:0.5rem;">
              <i class="bi bi-exclamation-triangle me-1"></i> Fehlgeschlagene Benutzer ({{ usersStore.failedUsers.length }})
            </div>
            <div v-for="u in usersStore.failedUsers" :key="u" style="font-family:monospace;font-size:0.8rem;color:#f85149;">{{ u }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Bulk create confirm -->
    <div v-if="bulkConfirm.show" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,0.6);">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              <i class="bi bi-person-plus me-2" style="color:#3fb950;"></i>
              Benutzer erstellen / aktualisieren
            </h5>
            <button type="button" class="btn-close" :disabled="usersStore.bulkRunning" @click="bulkConfirm.show = false"></button>
          </div>
          <div class="modal-body" style="font-size:0.875rem;">
            <p class="mb-2">
              <strong>{{ usersStore.csvEntries.length }}</strong> Benutzer werden erstellt oder aktualisiert.
            </p>
            <div
              class="alert mb-0 py-2"
              style="background:rgba(88,166,255,0.08);border:1px solid rgba(88,166,255,0.25);color:#e6edf3;font-size:0.83rem;"
            >
              <i class="bi bi-info-circle me-1" style="color:#58a6ff;"></i>
              UPN-Schema:
              <span style="font-family:monospace;color:#58a6ff;">{{ upnOrderLabel }}@{{ authStore.tenantDomain || 'domain' }}</span>
            </div>
            <p class="mt-3 mb-0" style="color:#8b949e;font-size:0.82rem;">
              Bitte bestätigen, dass die UPNs nach diesem Schema gebildet werden sollen.
            </p>
          </div>
          <div class="modal-footer">
            <button
              type="button"
              class="btn btn-secondary btn-sm"
              @click="usersStore.bulkRunning ? cancelRunningPs() : (bulkConfirm.show = false)"
            >
              {{ usersStore.bulkRunning ? 'Stoppen' : 'Abbrechen' }}
            </button>
            <button
              type="button"
              class="btn btn-success btn-sm"
              :disabled="usersStore.bulkRunning"
              @click="confirmBulkCreate"
            >
              <i class="bi" :class="usersStore.bulkRunning ? 'bi-arrow-repeat spin' : 'bi-play-fill'"></i>
              {{ usersStore.bulkRunning ? 'Läuft...' : 'Bestätigen &amp; starten' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, reactive } from 'vue'
import { useUsersStore } from '../stores/usersStore'
import { useAuthStore } from '../stores/authStore'
import { useUpnOrderStore } from '../stores/upnOrderStore'
import PasswordInput from '../components/PasswordInput.vue'
import UpnOrderRadios from '../components/UpnOrderRadios.vue'
import { validatePassword } from '../utils/passwordValidator.js'
import { buildUpn, buildUpnLocal, normalizeForUPN, UPN_ORDER_SURNAME_FIRST } from '../utils/upn.js'
import { cancelRunningPs } from '../utils/cancelPs'
import { downloadSampleCsv } from '../utils/downloadFile.js'

const usersStore = useUsersStore()
const authStore = useAuthStore()
const upnOrderStore = useUpnOrderStore()
const sampleCsvUrl = import.meta.env.BASE_URL + 'user-list.csv'

const tab = ref('single')
const pwValid = computed(() => validatePassword(singleForm.newPassword).valid)
const bulkConfirm = reactive({ show: false })

const upnOrderLabel = computed(() =>
  upnOrderStore.order === UPN_ORDER_SURNAME_FIRST ? 'nachname.vorname' : 'vorname.nachname'
)

const singleForm = reactive({
  vorname: '',
  nachname: '',
  abteilung: '',
  officeLocation: '',
  userType: 'Schüler',
  newPassword: '',
  forceChange: true
})

const singlePreview = computed(() => {
  if (!singleForm.vorname || !singleForm.nachname) return { upn: '', displayName: '' }
  const domain = authStore.tenantDomain || '?domain'
  return {
    upn: buildUpn(singleForm.vorname, singleForm.nachname, domain, upnOrderStore.order),
    displayName: `${singleForm.nachname} ${singleForm.vorname}`
  }
})

function entryLocalPart(entry) {
  return buildUpnLocal(entry?.vornameNormalized, entry?.nachnameNormalized, upnOrderStore.order)
}

function entryUpn(entry) {
  const domain = authStore.tenantDomain || ''
  const local = entryLocalPart(entry)
  if (!local || !domain) return ''
  return `${local}@${domain}`
}

function entryError(entry) {
  const upn = entryUpn(entry)
  return upn ? (usersStore.failedUserDetails?.[upn] || '') : ''
}

async function createSingleUser() {
  usersStore.bulkLogs = []
  usersStore.failedUsers = []
  usersStore.failedUserDetails = {}
  const vn = normalizeForUPN(singleForm.vorname)
  const nn = normalizeForUPN(singleForm.nachname)
  usersStore.csvEntries = [{
    vorname: singleForm.vorname,
    nachname: singleForm.nachname,
    vornameNormalized: vn,
    nachnameNormalized: nn,
    abteilung: singleForm.abteilung,
    officeLocation: singleForm.officeLocation,
    userType: singleForm.userType,
    newPassword: singleForm.newPassword,
    forceChange: singleForm.forceChange
  }]
  await usersStore.runBulkCreate()
  const upn = buildUpn(singleForm.vorname, singleForm.nachname, authStore.tenantDomain || '', upnOrderStore.order)
  const err = usersStore.failedUserDetails?.[upn]
  if (err) authStore.showToast(err, 'error')
  else {
    authStore.showToast('Benutzer erstellt', 'success')
    singleForm.vorname = ''
    singleForm.nachname = ''
    singleForm.newPassword = ''
    singleForm.abteilung = ''
    singleForm.officeLocation = ''
  }
  usersStore.csvEntries = []
}

async function importCsv() {
  await usersStore.importCsv()
  if (usersStore.csvEntries.length) tab.value = 'csv'
}

function addEmptyRow() {
  usersStore.csvEntries.push({
    vorname: '',
    nachname: '',
    vornameNormalized: '',
    nachnameNormalized: '',
    abteilung: '',
    officeLocation: '',
    userType: 'Schüler',
    newPassword: '',
    forceChange: true
  })
}

function openBulkConfirm() {
  if (!usersStore.csvEntries.length) return
  bulkConfirm.show = true
}

async function confirmBulkCreate() {
  if (!usersStore.csvEntries.length) return
  usersStore.bulkLogs = []
  usersStore.failedUsers = []
  usersStore.failedUserDetails = {}
  await usersStore.runBulkCreate()
  bulkConfirm.show = false
}
</script>

<style scoped>
.spin { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.row-has-error { background: rgba(248,81,73,0.06); }
</style>
