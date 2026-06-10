<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com> -->

<template>
    <div>
        <!-- Header -->
        <div class="page-header">
            <h1 class="page-title">Geräte entfernen</h1>
            <p class="page-subtitle">Geräte von Schulabgängern per CSV (Besitzer) identifizieren und aus dem Tenant entfernen</p>
        </div>

        <div class="content-card">
            <div class="content-card-body">
                <!-- Import Area -->
                <div class="d-flex gap-2 mb-3">
                    <button class="btn btn-primary" @click="importCsv" :disabled="running">
                        <i class="bi bi-upload me-1"></i> CSV-Datei importieren
                    </button>
                    <button v-if="csvEntries.length" class="btn btn-outline-secondary" @click="csvEntries = []">
                        <i class="bi bi-x-circle me-1"></i> Liste leeren
                    </button>
                </div>

                <!-- CSV Format Info -->
                <div v-if="!csvEntries.length" class="mb-4">
                    <div style="background:rgba(88,166,255,0.06);border:1px solid rgba(88,166,255,0.15);border-radius:6px;padding:1rem;">
                        <div style="font-size:0.85rem;font-weight:600;margin-bottom:0.5rem;">
                            <i class="bi bi-info-circle me-1" style="color:#58a6ff;"></i> CSV-Format
                        </div>
                        <pre style="font-family:monospace;font-size:0.78rem;color:#8b949e;margin:0;white-space:pre-wrap;">Vorname;Nachname
Max;Mustermann
Anna;Schmidt</pre>
                        <div style="font-size:0.78rem;color:#8b949e;margin-top:0.5rem;">
                            Nur <strong>Vorname</strong> + <strong>Nachname</strong> werden verwendet. Der Besitzer-UPN
                            wird daraus gebildet (<span style="font-family:monospace;">nachname.vorname@{{ domain || 'domain' }}</span>)
                            und gegen den Besitzer der geladenen Geräte abgeglichen. Pro Schüler werden <strong>alle</strong>
                            zugeordneten Geräte entfernt: Intune-verwaltete werden abgekoppelt (Retire), reine
                            Entra-Geräte aus dem Verzeichnis gelöscht.
                        </div>
                    </div>
                </div>

                <!-- Devicelist required hint -->
                <div v-if="csvEntries.length && !devicesStore.devices.length" class="mb-3">
                    <div class="alert mb-0" style="background:rgba(210,153,34,0.1);border:1px solid rgba(210,153,34,0.3);color:#d29922;border-radius:6px;">
                        <i class="bi bi-exclamation-triangle me-2"></i>
                        Geräteliste ist nicht geladen — ohne sie kann kein Abgleich erfolgen.
                        <button class="btn btn-sm btn-outline-secondary ms-2" :disabled="devicesStore.loading" @click="devicesStore.fetchDevices()">
                            <i class="bi" :class="devicesStore.loading ? 'bi-arrow-repeat spin' : 'bi-pc-display'"></i>
                            {{ devicesStore.loading ? 'Lädt...' : 'Geräteliste laden' }}
                        </button>
                    </div>
                </div>

                <!-- Domain missing hint -->
                <div v-if="csvEntries.length && !domain" class="mb-3">
                    <div class="alert mb-0" style="background:rgba(210,153,34,0.1);border:1px solid rgba(210,153,34,0.3);color:#d29922;border-radius:6px;">
                        <i class="bi bi-exclamation-triangle me-2"></i>
                        Keine Tenant-Domain bekannt — bitte zuerst die Benutzer- oder Geräteliste laden.
                    </div>
                </div>

                <!-- Preview Table -->
                <div v-if="csvEntries.length">
                    <div class="d-flex align-items-center justify-content-between mb-2">
                        <span style="font-size:0.875rem;">
                            <span style="color:#3fb950;font-weight:600;">{{ devicesToRemove.length }} Geräte gefunden</span>
                            <span style="color:#8b949e;"> · {{ matchedRows.length }} Schüler mit Geräten</span>
                            <span style="color:#8b949e;"> · {{ unmatchedRows.length }} ohne Geräte</span>
                        </span>
                        <button
                            class="btn btn-danger"
                            :disabled="!devicesToRemove.length || running"
                            @click="openConfirm"
                        >
                            <i class="bi bi-trash me-1"></i> {{ devicesToRemove.length }} Geräte entfernen
                        </button>
                    </div>

                    <div class="table-ms365-hscroll table-ms365-hscroll--y">
                        <table class="table table-ms365">
                            <thead>
                                <tr>
                                    <th>#</th>
                                    <th>Vorname</th>
                                    <th>Nachname</th>
                                    <th>Besitzer-UPN</th>
                                    <th>Geräte</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr v-for="(row, i) in rows" :key="i">
                                    <td style="color:#8b949e;">{{ i + 1 }}</td>
                                    <td>{{ row.entry.vorname }}</td>
                                    <td>{{ row.entry.nachname }}</td>
                                    <td style="font-family:monospace;font-size:0.72rem;color:#8b949e;">{{ row.upn || '—' }}</td>
                                    <td>
                                        <span v-if="row.devices.length" style="color:#3fb950;font-size:0.8rem;">
                                            <i class="bi bi-check-circle-fill me-1"></i>
                                            {{ row.devices.length }} Gerät(e)
                                            <span class="text-secondary">— {{ deviceSummary(row.devices) }}</span>
                                        </span>
                                        <span v-else style="color:#8b949e;font-size:0.8rem;">
                                            <i class="bi bi-dash-circle me-1"></i> keine Geräte
                                        </span>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>

        <!-- Confirm modal -->
        <div v-if="confirm.show" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,0.6);">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">
                            <i class="bi bi-trash me-2" style="color:#f85149;"></i>
                            Geräte entfernen (CSV)
                        </h5>
                        <button type="button" class="btn-close" :disabled="running" @click="confirm.show = false"></button>
                    </div>
                    <div class="modal-body">
                        <div class="alert" style="background:rgba(248,81,73,0.1);border:1px solid rgba(248,81,73,0.25);color:#f85149;border-radius:6px;">
                            <i class="bi bi-exclamation-triangle-fill me-2"></i>
                            <strong>Achtung:</strong> {{ devicesToRemove.length }} Geräte werden vollständig aus dem Tenant entfernt.
                            Intune-verwaltete werden abgekoppelt (Retire) und das Entra-Objekt gelöscht, reine Entra-Geräte nur gelöscht.
                        </div>
                        <ul class="list-unstyled mb-3 small" style="color:#8b949e;max-height:240px;overflow:auto;">
                            <li v-for="d in devicesToRemove" :key="d.id" class="py-1 border-bottom border-secondary border-opacity-25 d-flex justify-content-between">
                                <span>{{ d.displayName || d.id }} <span class="text-secondary font-monospace" style="font-size:0.72rem;">{{ d.ownerUserPrincipalName }}</span></span>
                                <span class="badge rounded-pill" :style="d.isIntuneManaged ? 'background:#1f6feb;color:#fff;' : 'background:#30363d;color:#8b949e;'">
                                    {{ d.isIntuneManaged ? 'Retire + Delete' : 'Entra-Delete' }}
                                </span>
                            </li>
                        </ul>
                        <label class="form-label">Zur Bestätigung <strong>{{ confirmWord }}</strong> eintippen</label>
                        <input v-model="confirm.text" type="text" class="form-control" style="font-family:monospace;" :disabled="running" />
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary btn-sm" :disabled="running" @click="confirm.show = false">Abbrechen</button>
                        <button
                            type="button"
                            class="btn btn-danger btn-sm"
                            :disabled="running || confirm.text !== confirmWord"
                            @click="runRemove"
                        >
                            <i class="bi bi-trash me-1"></i>
                            {{ running ? 'Entfernt...' : 'Alle entfernen' }}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, computed, reactive } from 'vue'
import { useDevicesStore } from '../stores/devicesStore'
import { useAuthStore } from '../stores/authStore'
import { buildUpn } from '../utils/upn.js'

const devicesStore = useDevicesStore()
const authStore = useAuthStore()

const confirmWord = 'LÖSCHEN'
const confirm = reactive({ show: false, text: '' })
const running = ref(false)
const csvEntries = ref([])

const domain = computed(() => authStore.tenantDomain || '')

// Lowercased owner-UPN -> list of devices owned by that user, for matching CSV rows.
const devicesByOwner = computed(() => {
    const m = new Map()
    for (const d of devicesStore.devices) {
        const upn = String(d.ownerUserPrincipalName || '').toLowerCase()
        if (!upn) continue
        if (!m.has(upn)) m.set(upn, [])
        m.get(upn).push(d)
    }
    return m
})

// Reconstruct owner-UPN per CSV row (same logic as create) and collect that owner's devices.
const rows = computed(() =>
    csvEntries.value.map((entry) => {
        const upn = buildUpn(entry.vorname, entry.nachname, domain.value)
        const devices = upn ? (devicesByOwner.value.get(upn.toLowerCase()) || []) : []
        return { entry, upn, devices }
    })
)

const matchedRows = computed(() => rows.value.filter((r) => r.devices.length))
const unmatchedRows = computed(() => rows.value.filter((r) => !r.devices.length))
const devicesToRemove = computed(() => matchedRows.value.flatMap((r) => r.devices))

// Short "2 Intune / 1 Entra" style summary for the preview row.
function deviceSummary(devices) {
    const intune = devices.filter((d) => d.isIntuneManaged).length
    const entra = devices.length - intune
    const parts = []
    if (intune) parts.push(`${intune} Intune`)
    if (entra) parts.push(`${entra} Entra`)
    return parts.join(' / ')
}

async function importCsv() {
    const result = await window.ipcRenderer.invoke('open-csv-dialog')
    if (result.status === 'cancelled') return
    if (result.status !== 'ok') {
        authStore.showToast(result.message || 'Importfehler', 'error')
        return
    }
    const dataResult = await window.ipcRenderer.invoke('get-csv-data')
    if (dataResult.status === 'ok') {
        csvEntries.value = dataResult.data
        authStore.showToast(`${dataResult.data.length} Einträge importiert`, 'success')
        if (!devicesStore.devices.length) devicesStore.fetchDevices()
    }
}

function openConfirm() {
    if (!devicesToRemove.value.length) return
    confirm.text = ''
    confirm.show = true
}

async function runRemove() {
    const rowsToRemove = devicesToRemove.value
    if (!rowsToRemove.length) return
    running.value = true
    try {
        await devicesStore.removeDevicesAutoBatch(rowsToRemove)
        confirm.show = false
    } finally {
        running.value = false
    }
}
</script>

<style scoped>
.spin { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
