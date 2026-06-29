<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com> -->

<template>
    <div>
        <!-- Header -->
        <div class="page-header">
            <h1 class="page-title">Backup</h1>
            <p class="page-subtitle">Tenant-Daten sichern oder aus einer JSON-Datei wiederherstellen</p>
        </div>

        <!-- Tabs -->
        <ul class="nav nav-tabs mb-0">
            <li class="nav-item">
                <button class="nav-link" :class="{ active: tab === 'create' }" @click="tab = 'create'">
                    <i class="bi bi-download me-1"></i> Backup erstellen
                </button>
            </li>
            <li class="nav-item">
                <button class="nav-link" :class="{ active: tab === 'restore' }" @click="tab = 'restore'">
                    <i class="bi bi-upload me-1"></i> Backup wiederherstellen
                </button>
            </li>
        </ul>

        <!-- Create Tab -->
        <div v-if="tab === 'create'" class="content-card" style="border-top-left-radius:0;">
            <div class="content-card-body">
                <div style="max-width:700px;">
                    <label class="form-label mb-2">Was soll gesichert werden?</label>

                    <div class="form-check mb-2">
                        <input class="form-check-input" type="checkbox" id="bkUsers" v-model="sel.users" />
                        <label class="form-check-label" for="bkUsers">
                            <strong>Benutzer</strong>
                            <span style="color:#8b949e;font-size:0.8rem;"> — Stammdaten + Lizenz-SKUs (kein Passwort)</span>
                        </label>
                    </div>
                    <div class="form-check mb-2">
                        <input class="form-check-input" type="checkbox" id="bkGroups" v-model="sel.groups" />
                        <label class="form-check-label" for="bkGroups">
                            <strong>Gruppen</strong>
                            <span style="color:#8b949e;font-size:0.8rem;"> — inkl. Mitglieder + Owner</span>
                        </label>
                    </div>
                    <div class="form-check mb-2">
                        <input class="form-check-input" type="checkbox" id="bkRoles" v-model="sel.roles" />
                        <label class="form-check-label" for="bkRoles">
                            <strong>Rollen</strong>
                            <span style="color:#8b949e;font-size:0.8rem;"> — Verzeichnisrollen + zugewiesene Benutzer</span>
                        </label>
                    </div>
                    <div class="form-check mb-2">
                        <input class="form-check-input" type="checkbox" id="bkIntune" v-model="sel.intunePolicies" />
                        <label class="form-check-label" for="bkIntune">
                            <strong>Intune-Geräterichtlinien</strong>
                            <span style="color:#8b949e;font-size:0.8rem;"> — Settings Catalog + Compliance</span>
                        </label>
                    </div>
                    <div class="form-check mb-3">
                        <input class="form-check-input" type="checkbox" id="bkIntuneApps" v-model="sel.intuneAppPolicies" />
                        <label class="form-check-label" for="bkIntuneApps">
                            <strong>Intune App-Richtlinien</strong>
                            <span style="color:#8b949e;font-size:0.8rem;"> — App-Schutz + App-Konfiguration (iOS/Android/Windows)</span>
                        </label>
                    </div>

                    <div class="info-box mb-3">
                        <i class="bi bi-info-circle me-1" style="color:#58a6ff;"></i>
                        Gast-Konten, synchronisierte Benutzer und dynamische Gruppen werden ausgelassen — sie lassen sich nicht sauber wiederherstellen.
                        Geräte sind über die API nicht wiederherstellbar und daher nicht enthalten.
                        Intune: Regeln/Zuweisungen und App-Schutz/Konfiguration — keine App-Installationspakete (.ipa/.apk).
                    </div>

                    <div class="d-flex gap-2">
                        <button v-if="backupStore.running" class="btn btn-outline-danger" @click="cancelRunningPs">
                            <i class="bi bi-stop-fill"></i> Stoppen
                        </button>
                        <button class="btn btn-success" :disabled="backupStore.running || !anySelected" @click="runBackup">
                            <i class="bi" :class="backupStore.running ? 'bi-arrow-repeat spin' : 'bi-download'"></i>
                            {{ backupStore.running ? 'Sichert...' : 'Backup erstellen' }}
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Restore Tab -->
        <div v-if="tab === 'restore'" class="content-card" style="border-top-left-radius:0;">
            <div class="content-card-body">
                <div style="max-width:700px;">
                    <button class="btn btn-primary mb-3" :disabled="backupStore.restoring" @click="pickBackup">
                        <i class="bi bi-folder2-open me-1"></i> Backup-Datei wählen
                    </button>

                    <div v-if="preview" class="mb-3">
                        <!-- File preview -->
                        <div class="info-box mb-3">
                            <div style="font-size:0.82rem;color:#e6edf3;font-family:monospace;word-break:break-all;">{{ preview.filePath }}</div>
                            <div style="font-size:0.78rem;color:#8b949e;margin-top:0.4rem;">
                                Erstellt: {{ formatDate(preview.createdAt) }} ·
                                Tenant: {{ preview.tenantDomain || 'unbekannt' }} ·
                                Schema v{{ preview.schemaVersion ?? '?' }}
                            </div>
                        </div>

                        <!-- Tenant mismatch warning -->
                        <div v-if="tenantMismatch" class="alert mb-3" style="background:rgba(248,81,73,0.1);border:1px solid rgba(248,81,73,0.3);color:#f85149;border-radius:6px;">
                            <i class="bi bi-exclamation-triangle-fill me-2"></i>
                            Backup stammt aus Tenant <strong>{{ preview.tenantDomain }}</strong>, verbunden bist du mit
                            <strong>{{ authStore.tenantDomain }}</strong>. Wiederherstellung trotzdem möglich, aber bitte sicher prüfen.
                        </div>

                        <label class="form-label mb-2">Was soll wiederhergestellt werden?</label>
                        <div class="form-check mb-2">
                            <input class="form-check-input" type="checkbox" id="rsUsers" v-model="rsel.users" :disabled="!preview.counts.users" />
                            <label class="form-check-label" for="rsUsers">
                                <strong>Benutzer</strong> <span style="color:#8b949e;font-size:0.8rem;">({{ preview.counts.users }})</span>
                            </label>
                        </div>
                        <div class="form-check mb-2">
                            <input class="form-check-input" type="checkbox" id="rsGroups" v-model="rsel.groups" :disabled="!preview.counts.groups" />
                            <label class="form-check-label" for="rsGroups">
                                <strong>Gruppen</strong> <span style="color:#8b949e;font-size:0.8rem;">({{ preview.counts.groups }})</span>
                            </label>
                        </div>
                        <div class="form-check mb-2">
                            <input class="form-check-input" type="checkbox" id="rsRoles" v-model="rsel.roles" :disabled="!preview.counts.roles" />
                            <label class="form-check-label" for="rsRoles">
                                <strong>Rollen</strong> <span style="color:#8b949e;font-size:0.8rem;">({{ preview.counts.roles }})</span>
                            </label>
                        </div>
                        <div class="form-check mb-2">
                            <input class="form-check-input" type="checkbox" id="rsIntune" v-model="rsel.intunePolicies" :disabled="!preview.counts.intunePolicies" />
                            <label class="form-check-label" for="rsIntune">
                                <strong>Intune-Geräterichtlinien</strong> <span style="color:#8b949e;font-size:0.8rem;">({{ preview.counts.intunePolicies }})</span>
                            </label>
                        </div>
                        <div class="form-check mb-3">
                            <input class="form-check-input" type="checkbox" id="rsIntuneApps" v-model="rsel.intuneAppPolicies" :disabled="!preview.counts.intuneAppPolicies" />
                            <label class="form-check-label" for="rsIntuneApps">
                                <strong>Intune App-Richtlinien</strong> <span style="color:#8b949e;font-size:0.8rem;">({{ preview.counts.intuneAppPolicies }})</span>
                            </label>
                        </div>

                        <!-- Start password (only needed when restoring users) -->
                        <div v-if="rsel.users" class="mb-3">
                            <label class="form-label">Start-Passwort für neue Benutzer <span style="color:#f85149;">*</span></label>
                            <PasswordInput v-model="startPassword" hints-position="side" />
                            <div style="font-size:0.75rem;color:#8b949e;margin-top:0.25rem;">
                                Gilt für alle neu angelegten Benutzer. Muss bei der ersten Anmeldung geändert werden.
                            </div>
                        </div>

                        <div class="info-box mb-3">
                            <i class="bi bi-info-circle me-1" style="color:#58a6ff;"></i>
                            Bestehende Objekte (gleicher UPN / Mail-Nickname / Richtlinienname) werden <strong>übersprungen</strong>, nur Fehlende neu angelegt.
                            Intune-Zuweisungen brauchen vorhandene Gruppen — <strong>Gruppen zuerst</strong> wiederherstellen.
                        </div>

                        <div class="d-flex gap-2">
                            <button v-if="backupStore.restoring" class="btn btn-outline-danger" @click="cancelRunningPs">
                                <i class="bi bi-stop-fill"></i> Stoppen
                            </button>
                            <button
                                class="btn btn-success"
                                :disabled="backupStore.restoring || !anyRestoreSelected || (rsel.users && !pwValid)"
                                @click="runRestore"
                            >
                                <i class="bi" :class="backupStore.restoring ? 'bi-arrow-repeat spin' : 'bi-upload'"></i>
                                {{ backupStore.restoring ? 'Stellt wieder her...' : 'Wiederherstellen' }}
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, reactive, computed } from 'vue'
import { useBackupStore } from '../stores/backupStore'
import { useAuthStore } from '../stores/authStore'
import PasswordInput from '../components/PasswordInput.vue'
import { validatePassword } from '../utils/passwordValidator.js'
import { cancelRunningPs } from '../utils/cancelPs'

const backupStore = useBackupStore()
const authStore = useAuthStore()

const tab = ref('create')

// --- Create ---
const sel = reactive({ users: true, groups: true, roles: true, intunePolicies: false, intuneAppPolicies: false })
const anySelected = computed(() => sel.users || sel.groups || sel.roles || sel.intunePolicies || sel.intuneAppPolicies)

async function runBackup() {
    const categories = []
    if (sel.users) categories.push('users')
    if (sel.groups) categories.push('groups')
    if (sel.roles) categories.push('roles')
    if (sel.intunePolicies) categories.push('intunePolicies')
    if (sel.intuneAppPolicies) categories.push('intuneAppPolicies')
    await backupStore.runBackup(categories)
}

// --- Restore ---
const preview = ref(null)
const rsel = reactive({ users: false, groups: false, roles: false, intunePolicies: false, intuneAppPolicies: false })
const startPassword = ref('')
const pwValid = computed(() => validatePassword(startPassword.value).valid)
const anyRestoreSelected = computed(() => rsel.users || rsel.groups || rsel.roles || rsel.intunePolicies || rsel.intuneAppPolicies)
const tenantMismatch = computed(() =>
    !!preview.value?.tenantDomain && !!authStore.tenantDomain && preview.value.tenantDomain !== authStore.tenantDomain
)

function formatDate(iso) {
    if (!iso) return 'unbekannt'
    const d = new Date(iso)
    return isNaN(d) ? iso : d.toLocaleString('de-AT')
}

async function pickBackup() {
    const res = await backupStore.pickBackup()
    if (!res) return
    preview.value = res
    // Preselect categories that actually contain data.
    rsel.users = !!res.counts.users
    rsel.groups = !!res.counts.groups
    rsel.roles = !!res.counts.roles
    rsel.intunePolicies = !!res.counts.intunePolicies
    rsel.intuneAppPolicies = !!res.counts.intuneAppPolicies
}

async function runRestore() {
    if (!preview.value) return
    const categories = []
    if (rsel.users) categories.push('users')
    if (rsel.groups) categories.push('groups')
    if (rsel.roles) categories.push('roles')
    if (rsel.intunePolicies) categories.push('intunePolicies')
    if (rsel.intuneAppPolicies) categories.push('intuneAppPolicies')
    await backupStore.runRestore({
        backupPath: preview.value.filePath,
        categories,
        defaultPassword: rsel.users ? startPassword.value : ''
    })
}
</script>

<style scoped>
.spin { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.info-box {
    background: rgba(88, 166, 255, 0.06);
    border: 1px solid rgba(88, 166, 255, 0.15);
    border-radius: 6px;
    padding: 0.75rem 1rem;
    font-size: 0.8rem;
    color: #8b949e;
}
</style>
