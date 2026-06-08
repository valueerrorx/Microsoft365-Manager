<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com> -->

<template>
    <div>
        <!-- Header -->
        <div class="page-header">
            <h1 class="page-title">Gruppe erstellen</h1>
            <p class="page-subtitle">Sicherheitsgruppe oder Microsoft-365-Gruppe anlegen</p>
        </div>

        <div class="content-card">
            <div class="content-card-body">
                <div class="row g-3" style="max-width:700px;">
                    <div class="col-12">
                        <label class="form-label">Gruppenname <span style="color:#f85149;">*</span></label>
                        <input v-model="form.displayName" type="text" class="form-control" placeholder="z.B. 3AHIT Projektteam" />
                    </div>
                    <div class="col-12">
                        <label class="form-label">Beschreibung</label>
                        <input v-model="form.description" type="text" class="form-control" placeholder="Optional" />
                    </div>
                    <div class="col-6">
                        <label class="form-label">Typ</label>
                        <select v-model="form.type" class="form-select">
                            <option value="security">Sicherheitsgruppe</option>
                            <option value="unified">Microsoft 365 (Teams/Postfach)</option>
                        </select>
                    </div>
                    <div v-if="form.type === 'unified'" class="col-6">
                        <label class="form-label">Sichtbarkeit</label>
                        <select v-model="form.visibility" class="form-select">
                            <option value="Private">Privat</option>
                            <option value="Public">Öffentlich</option>
                        </select>
                    </div>
                    <div v-if="form.type === 'unified'" class="col-12">
                        <label class="form-label">Mail-Nickname</label>
                        <input v-model="form.mailNickname" type="text" class="form-control" :placeholder="autoNickname || 'wird aus dem Namen abgeleitet'" />
                        <div style="font-size:0.75rem;color:#8b949e;margin-top:0.25rem;">
                            Leer lassen → automatisch aus dem Gruppennamen. Nur Buchstaben/Ziffern.
                        </div>
                    </div>
                    <div class="col-12">
                        <label class="form-label">Owner (UPNs, kommagetrennt)</label>
                        <input v-model="form.ownerUpns" type="text" class="form-control" placeholder="max.mustermann@domain, anna.schmidt@domain" />
                        <div style="font-size:0.75rem;color:#8b949e;margin-top:0.25rem;">
                            Optional. Microsoft-365-Gruppen sollten mindestens einen Owner haben.
                        </div>
                    </div>
                    <div class="col-12">
                        <button
                            class="btn btn-success"
                            :disabled="running || !form.displayName.trim()"
                            @click="createGroup"
                        >
                            <i class="bi" :class="running ? 'bi-arrow-repeat spin' : 'bi-collection'"></i>
                            {{ running ? 'Erstellt...' : 'Gruppe erstellen' }}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, reactive, computed } from 'vue'
import { useGroupsStore } from '../stores/groupsStore'

const groupsStore = useGroupsStore()
const running = ref(false)

const form = reactive({
    displayName: '',
    description: '',
    type: 'security',
    visibility: 'Private',
    mailNickname: '',
    ownerUpns: ''
})

// Preview of the auto-derived mailNickname so the user sees what unified groups will get.
const autoNickname = computed(() =>
    form.displayName.replace(/[^A-Za-z0-9]/g, '').toLowerCase()
)

async function createGroup() {
    if (!form.displayName.trim() || running.value) return
    running.value = true
    try {
        const { ok } = await groupsStore.createGroup({
            displayName: form.displayName.trim(),
            description: form.description.trim(),
            type: form.type,
            visibility: form.visibility,
            mailNickname: form.mailNickname.trim(),
            ownerUpns: form.ownerUpns.trim()
        })
        if (ok) {
            form.displayName = ''
            form.description = ''
            form.mailNickname = ''
            form.ownerUpns = ''
        }
    } finally {
        running.value = false
    }
}
</script>

<style scoped>
.spin { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
