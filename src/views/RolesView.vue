<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com> -->

<template>
  <div>
    <div class="page-header d-flex align-items-center justify-content-between flex-wrap gap-2">
      <div>
        <h1 class="page-title">Administratorenrollen</h1>
        <p class="page-subtitle">Verwaltete Microsoft-Entra-Verzeichnisrollen</p>
      </div>
      <button
        class="btn btn-outline-secondary btn-sm"
        :disabled="rolesStore.loading"
        @click="rolesStore.fetchManagedRoles()"
      >
        <i class="bi bi-arrow-clockwise me-1" :class="{ spin: rolesStore.loading }"></i>
        Aktualisieren
      </button>
    </div>

    <div v-if="!usersStore.users.length" class="content-card mb-3">
      <div class="content-card-body py-2 px-3" style="font-size:0.85rem;color:#d29922;">
        <i class="bi bi-info-circle me-1"></i>
        Für „Benutzer hinzufügen“ zuerst die
        <RouterLink to="/users" style="color:#58a6ff;">Benutzerliste</RouterLink>
        laden.
      </div>
    </div>

    <div v-if="rolesStore.loading" class="text-center py-5">
      <div class="spinner-border" style="color:#58a6ff;" role="status"></div>
      <div style="color:#8b949e;margin-top:1rem;font-size:0.875rem;">
        {{ authStore.connected ? 'Rollen werden geladen…' : 'Verbinde mit Microsoft Graph…' }}
      </div>
    </div>

    <div v-else-if="!rolesStore.roles.length" class="text-center py-5">
      <i class="bi bi-shield-lock" style="font-size:3rem;color:#30363d;"></i>
      <div style="color:#8b949e;margin-top:1rem;">
        {{ authStore.connected ? 'Noch keine Rollen geladen' : 'Nicht mit Microsoft Graph verbunden' }}
      </div>
      <p v-if="!authStore.connected" class="mt-2 mb-0" style="font-size:0.85rem;color:#8b949e;">
        Beim ersten Start öffnet sich ein Browser-Fenster oder ein Anmeldecode erscheint.
      </p>
      <button class="btn btn-primary btn-sm mt-3" @click="rolesStore.fetchManagedRoles()">
        <i class="bi bi-plug me-1"></i> {{ authStore.connected ? 'Rollen laden' : 'Verbinden &amp; laden' }}
      </button>
    </div>

    <div v-else class="row g-3">
      <div class="col-12 col-lg-4">
        <div class="content-card">
          <div class="content-card-body p-0">
            <div
              v-for="r in sortedRoles"
              :key="r.templateId"
              class="role-list-item"
              :class="{ active: selectedTemplateId === r.templateId }"
              @click="selectRole(r.templateId)"
            >
              <div class="d-flex align-items-start gap-2">
                <i
                  class="bi mt-1"
                  :class="r.dangerous ? 'bi-shield-exclamation text-danger' : 'bi-shield-check'"
                  :style="r.dangerous ? '' : 'color:#58a6ff;'"
                ></i>
                <div class="flex-grow-1 min-w-0">
                  <div style="font-weight:500;font-size:0.875rem;">{{ r.label }}</div>
                  <div v-if="r.loadError" style="font-size:0.72rem;color:#f85149;">{{ r.loadError }}</div>
                  <div v-else style="font-size:0.72rem;color:#8b949e;">
                    {{ r.memberCount ?? 0 }} Benutzer
                  </div>
                </div>
                <span
                  class="badge rounded-pill"
                  style="font-size:0.7rem;background:rgba(88,166,255,0.15);color:#58a6ff;"
                >
                  {{ r.memberCount ?? 0 }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="col-12 col-lg-8">
        <div v-if="selectedRole" class="content-card">
          <div class="content-card-body">
            <div class="d-flex align-items-start justify-content-between flex-wrap gap-2 mb-3">
              <div>
                <h2 style="font-size:1.05rem;margin:0;color:#e6edf3;">{{ selectedRole.label }}</h2>
                <div style="font-size:0.78rem;color:#8b949e;">
                  {{ selectedRole.memberCount ?? 0 }}
                  {{ (selectedRole.memberCount ?? 0) === 1 ? 'Benutzer' : 'Benutzer' }}
                  mit dieser Rolle
                </div>
              </div>
              <span v-if="selectedRole.dangerous" class="badge rounded-pill" style="background:rgba(248,81,73,0.15);color:#f85149;">
                Privilegierte Rolle
              </span>
            </div>

            <div v-if="selectedRole.loadError" class="alert mb-3" style="background:rgba(248,81,73,0.1);border:1px solid rgba(248,81,73,0.25);color:#f85149;font-size:0.85rem;">
              {{ selectedRole.loadError }}
            </div>

            <div class="mb-3">
              <label class="form-label">Mitglieder suchen</label>
              <div class="input-group input-group-sm">
                <span class="input-group-text"><i class="bi bi-search"></i></span>
                <input v-model="memberSearch" type="text" class="form-control" placeholder="Name oder UPN…" />
              </div>
            </div>

            <div v-if="filteredMembers.length" class="table-ms365-hscroll">
              <table class="table table-ms365 table-sm">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>UPN</th>
                    <th>Läuft ab</th>
                    <th style="width:80px;"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="m in filteredMembers" :key="m.id">
                    <td>{{ m.displayName || '—' }}</td>
                    <td style="font-family:monospace;font-size:0.8rem;color:#8b949e;">{{ m.userPrincipalName || m.mail || '—' }}</td>
                    <td style="font-size:0.78rem;white-space:nowrap;">
                      <span v-if="memberExpirationLabel(m)" style="color:#d29922;">{{ memberExpirationLabel(m) }}</span>
                      <span v-else style="color:#8b949e;" title="Nur bei Zuweisung mit „Temporär zuweisen“">dauerhaft</span>
                    </td>
                    <td>
                      <button
                        type="button"
                        class="btn-action danger"
                        title="Aus Rolle entfernen"
                        :disabled="busy"
                        @click="requestRemoveMember(m)"
                      >
                        <i class="bi bi-person-dash"></i>
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div v-else style="font-size:0.85rem;color:#8b949e;">Keine Benutzer in dieser Rolle.</div>

            <hr style="border-color:#30363d;margin:1.25rem 0;" />

            <div style="font-size:0.875rem;font-weight:500;margin-bottom:0.5rem;">Benutzer hinzufügen</div>
            <div class="input-group input-group-sm mb-2">
              <span class="input-group-text"><i class="bi bi-search"></i></span>
              <input
                v-model="addUserSearch"
                type="text"
                class="form-control"
                placeholder="Benutzer suchen…"
                :disabled="!usersStore.users.length"
              />
            </div>
            <div v-if="addUserIds.length" class="mb-2" style="font-size:0.8rem;color:#58a6ff;">
              <i class="bi bi-check2-square me-1"></i>
              {{ addUserIds.length }} Benutzer ausgewählt
              <button type="button" class="btn btn-link btn-sm p-0 ms-2" style="font-size:0.78rem;color:#8b949e;" @click="addUserIds = []">
                Auswahl aufheben
              </button>
            </div>
            <div v-if="usersToAdd.length" class="add-user-pick-list mb-2">
              <label
                v-for="u in usersToAdd"
                :key="u.id"
                class="add-user-pick-row d-flex align-items-center gap-2 py-2 px-2"
                :class="{ 'is-selected': isAddUserSelected(u.id) }"
              >
                <input
                  v-model="addUserIds"
                  type="checkbox"
                  class="form-check-input flex-shrink-0"
                  :value="u.id"
                  :disabled="busy"
                />
                <span class="flex-grow-1 min-w-0" style="font-size:0.82rem;line-height:1.3;">
                  <span style="color:#e6edf3;">{{ u.displayName || '—' }}</span>
                  <span class="d-block" style="color:#8b949e;font-family:monospace;font-size:0.75rem;">{{ u.userPrincipalName }}</span>
                </span>
                <i v-if="isAddUserSelected(u.id)" class="bi bi-check-circle-fill flex-shrink-0" style="color:#58a6ff;font-size:1rem;" aria-hidden="true"></i>
              </label>
            </div>
            <div v-else-if="usersStore.users.length" style="font-size:0.8rem;color:#8b949e;">
              Keine passenden Benutzer (oder alle bereits Mitglied).
            </div>
            <div class="d-flex flex-wrap align-items-center gap-2 mt-1">
              <button
                type="button"
                class="btn btn-primary btn-sm"
                :disabled="busy || !addUserIds.length || !selectedRole.directoryRoleId"
                @click="requestAddMembers"
              >
                <i class="bi bi-person-plus me-1"></i>
                {{ busy ? 'Wird zugewiesen…' : `Zur Rolle hinzufügen${addUserIds.length ? ` (${addUserIds.length})` : ''}` }}
              </button>
              <div class="form-check mb-0">
                <input id="roleAddTemporary" v-model="addTemporary" type="checkbox" class="form-check-input" :disabled="busy" />
                <label class="form-check-label" for="roleAddTemporary" style="font-size:0.85rem;">Temporär zuweisen</label>
              </div>
              <select
                v-if="addTemporary"
                v-model="temporaryDuration"
                class="form-select form-select-sm"
                style="width:auto;min-width:10rem;"
                :disabled="busy"
              >
                <option v-for="opt in durationOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
              </select>
            </div>
            <p v-if="addTemporary" class="mb-0 mt-2" style="font-size:0.75rem;color:#8b949e;line-height:1.35;">
              Die Rolle wird sofort vergeben. Die App entfernt sie nach Ablauf automatisch,
              sobald Sie angemeldet sind und die App läuft.
              <span v-if="temporaryEndsAtLabel" style="color:#58a6ff;"> Geplant bis {{ temporaryEndsAtLabel }}.</span>
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- Role add/remove confirm -->
    <div v-if="confirmModal.show" class="modal d-block" tabindex="-1" style="background:rgba(0,0,0,0.6);">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              <i
                class="bi me-2"
                :class="confirmModal.mode === 'remove' ? 'bi-person-dash text-danger' : 'bi-shield-exclamation text-danger'"
              ></i>
              {{ confirmModal.mode === 'remove' ? 'Aus Rolle entfernen' : 'Rolle zuweisen' }}
            </h5>
            <button type="button" class="btn-close" :disabled="busy" @click="closeConfirmModal"></button>
          </div>
          <div class="modal-body" style="font-size:0.875rem;">
            <div
              v-if="confirmModal.dangerous"
              class="alert mb-3 py-2"
              style="background:rgba(248,81,73,0.1);border:1px solid rgba(248,81,73,0.25);color:#f85149;font-size:0.83rem;"
            >
              <i class="bi bi-exclamation-triangle-fill me-1"></i>
              Privilegierte Rolle — diese Änderung kann weitreichende Auswirkungen haben.
            </div>
            <p v-if="confirmModal.mode === 'add'">
              <strong>{{ confirmModal.roleLabel }}</strong> an
              <strong>{{ confirmModal.userCount }}</strong>
              Benutzer zuweisen?
              <span v-if="confirmModal.temporary" class="d-block mt-1" style="color:#d29922;font-size:0.82rem;">
                Temporär: {{ confirmModal.durationLabel }}.
              </span>
            </p>
            <p v-else>
              <strong>{{ confirmModal.memberDisplayName || confirmModal.memberUpn }}</strong>
              <span v-if="confirmModal.memberUpn && confirmModal.memberDisplayName" style="color:#8b949e;font-size:0.8rem;">
                ({{ confirmModal.memberUpn }})
              </span>
              aus der Rolle <strong>{{ confirmModal.roleLabel }}</strong> entfernen?
            </p>
            <p v-if="confirmModal.dangerous" style="color:#8b949e;">
              Zur Bestätigung den Rollennamen exakt eintippen:
              <span style="color:#e6edf3;font-family:monospace;">{{ confirmModal.roleLabel }}</span>
            </p>
            <input
              v-if="confirmModal.dangerous"
              v-model="confirmModal.text"
              type="text"
              class="form-control form-control-sm"
              :disabled="busy"
              autocomplete="off"
            />
            <div v-if="confirmModal.error" class="mt-2" style="color:#f85149;font-size:0.83rem;">{{ confirmModal.error }}</div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary btn-sm" @click="busy ? cancelRunningPs() : closeConfirmModal()">{{ busy ? 'Stoppen' : 'Abbrechen' }}</button>
            <button
              type="button"
              class="btn btn-danger btn-sm"
              :disabled="busy || !confirmActionEnabled"
              @click="runConfirmedAction"
            >
              {{ confirmModal.mode === 'remove' ? (busy ? 'Entfernt…' : 'Entfernen') : (busy ? 'Weist zu…' : 'Zuweisen') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { storeToRefs } from 'pinia'
import { useAuthStore } from '../stores/authStore'
import { useRolesStore } from '../stores/rolesStore'
import { useUsersStore } from '../stores/usersStore'
import managedDirectoryRoles from '../../config/managed-directory-roles.json'
import { cancelRunningPs, resetPsCancel, psCancelRequested } from '../utils/cancelPs'

const roleSortIndex = new Map(
  managedDirectoryRoles.map((entry, index) => [entry.templateId, index])
)

const authStore = useAuthStore()
const rolesStore = useRolesStore()
const { scheduledExpirations } = storeToRefs(rolesStore)
const usersStore = useUsersStore()

const selectedTemplateId = ref(null)
const memberSearch = ref('')
const addUserSearch = ref('')
const addUserIds = ref([])
const addTemporary = ref(false)
const durationOptions = [
  { value: '2m', label: '2 Minuten (Test)', ms: 2 * 60 * 1000 },
  { value: '2h', label: '2 Stunden', ms: 2 * 60 * 60 * 1000 },
  { value: '4h', label: '4 Stunden', ms: 4 * 60 * 60 * 1000 },
  { value: '6h', label: '6 Stunden', ms: 6 * 60 * 60 * 1000 },
  { value: '8h', label: '8 Stunden', ms: 8 * 60 * 60 * 1000 },
  { value: '10h', label: '10 Stunden', ms: 10 * 60 * 60 * 1000 },
  { value: '12h', label: '12 Stunden', ms: 12 * 60 * 60 * 1000 },
  { value: '24h', label: '24 Stunden', ms: 24 * 60 * 60 * 1000 },
  { value: '48h', label: '48 Stunden', ms: 48 * 60 * 60 * 1000 }
]
const temporaryDuration = ref('4h')
const busy = ref(false)

function durationMsForValue(value) {
  const opt = durationOptions.find((o) => o.value === value)
  return opt?.ms ?? 4 * 60 * 60 * 1000
}

function durationLabelForValue(value) {
  const opt = durationOptions.find((o) => o.value === value)
  return opt?.label ?? String(value)
}

function normalizeGuid(value) {
  return String(value || '').trim().toLowerCase()
}

const memberExpirationByUserId = computed(() => {
  const role = selectedRole.value
  const map = new Map()
  if (!role?.templateId) return map
  const tid = normalizeGuid(role.templateId)
  for (const e of scheduledExpirations.value) {
    if (normalizeGuid(e.roleTemplateId) !== tid) continue
    const uid = normalizeGuid(e.userId)
    if (uid) map.set(uid, e)
    const upn = String(e.userPrincipalName || '').trim().toLowerCase()
    if (upn) map.set(`upn:${upn}`, e)
  }
  return map
})

const confirmModal = reactive({
  show: false,
  mode: 'add',
  roleLabel: '',
  roleTemplateId: '',
  dangerous: false,
  userIds: [],
  userCount: 0,
  userId: '',
  memberDisplayName: '',
  memberUpn: '',
  temporary: false,
  durationLabel: '4 Stunden',
  text: '',
  error: ''
})

const confirmActionEnabled = computed(() => {
  if (confirmModal.dangerous) return confirmModal.text === confirmModal.roleLabel
  return true
})

const sortedRoles = computed(() =>
  [...rolesStore.roles].sort((a, b) => {
    const ai = roleSortIndex.get(a.templateId) ?? 999
    const bi = roleSortIndex.get(b.templateId) ?? 999
    return ai - bi
  })
)

const selectedRole = computed(() =>
  rolesStore.roles.find((r) => r.templateId === selectedTemplateId.value) || null
)

const memberIdSet = computed(() => {
  const set = new Set()
  for (const m of selectedRole.value?.members || []) {
    if (m.id) set.add(normalizeGuid(m.id))
  }
  return set
})

const filteredMembers = computed(() => {
  const list = selectedRole.value?.members || []
  const q = memberSearch.value.trim().toLowerCase()
  if (!q) return list
  return list.filter(
    (m) =>
      (m.displayName || '').toLowerCase().includes(q) ||
      (m.userPrincipalName || '').toLowerCase().includes(q) ||
      (m.mail || '').toLowerCase().includes(q)
  )
})

const usersToAdd = computed(() => {
  const q = addUserSearch.value.trim().toLowerCase()
  let list = usersStore.users.filter((u) => u.id && !memberIdSet.value.has(normalizeGuid(u.id)))
  if (q) {
    list = list.filter(
      (u) =>
        (u.displayName || '').toLowerCase().includes(q) ||
        (u.userPrincipalName || '').toLowerCase().includes(q)
    )
  }
  return list.slice(0, 80)
})

function isAddUserSelected(id) {
  const sid = normalizeGuid(id)
  return addUserIds.value.some((x) => normalizeGuid(x) === sid)
}

const temporaryEndsAtLabel = computed(() => {
  if (!addTemporary.value) return ''
  const ms = durationMsForValue(temporaryDuration.value)
  if (!ms) return ''
  return new Date(Date.now() + ms).toLocaleString('de-AT', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
})

function memberExpirationLabel(m) {
  if (!m) return ''
  if (m.scheduledExpiresAt) {
    const t = new Date(m.scheduledExpiresAt).getTime()
    if (Number.isFinite(t)) {
      if (t <= Date.now()) return 'überfällig'
      return formatExpiryDate(t)
    }
  }
  const upn = String(m.userPrincipalName || m.mail || '').trim().toLowerCase()
  const exp =
    memberExpirationByUserId.value.get(normalizeGuid(m.id)) ||
    (upn ? memberExpirationByUserId.value.get(`upn:${upn}`) : null)
  if (!exp?.expiresAt) return ''
  const t = new Date(exp.expiresAt).getTime()
  if (!Number.isFinite(t)) return ''
  if (t <= Date.now()) return 'überfällig'
  return formatExpiryDate(t)
}

function formatExpiryDate(ms) {
  return new Date(ms).toLocaleString('de-AT', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

function selectRole(templateId) {
  selectedTemplateId.value = templateId
  memberSearch.value = ''
  addUserSearch.value = ''
  addUserIds.value = []
}

watch(
  () => rolesStore.roles.map((r) => r.templateId).join(','),
  () => {
    if (!rolesStore.roles.length) {
      selectedTemplateId.value = null
      return
    }
    if (!selectedTemplateId.value || !rolesStore.roles.some((r) => r.templateId === selectedTemplateId.value)) {
      selectedTemplateId.value = sortedRoles.value[0]?.templateId ?? null
    }
  }
)

function openConfirmModal({ mode, userIds = [], userId = '', member = null, temporary = false, duration = '4h' }) {
  if (!selectedRole.value) return
  confirmModal.show = true
  confirmModal.mode = mode
  confirmModal.roleLabel = selectedRole.value.label
  confirmModal.roleTemplateId = selectedRole.value.templateId
  confirmModal.dangerous = !!selectedRole.value.dangerous
  confirmModal.userIds = userIds
  confirmModal.userCount = userIds.length
  confirmModal.userId = userId
  confirmModal.memberDisplayName = member?.displayName || ''
  confirmModal.memberUpn = member?.userPrincipalName || member?.mail || ''
  confirmModal.temporary = !!temporary
  confirmModal.durationLabel = durationLabelForValue(duration)
  confirmModal.text = ''
  confirmModal.error = ''
}

function requestRemoveMember(m) {
  if (!selectedRole.value || !m.id) return
  openConfirmModal({ mode: 'remove', userId: m.id, member: m })
}

function requestAddMembers() {
  if (!selectedRole.value || !addUserIds.value.length) return
  const ids = [...addUserIds.value]
  if (selectedRole.value.dangerous) {
    openConfirmModal({ mode: 'add', userIds: ids, temporary: addTemporary.value, duration: temporaryDuration.value })
    return
  }
  void runAddMembers(ids, selectedRole.value.templateId)
}

function closeConfirmModal() {
  if (busy.value) return
  confirmModal.show = false
}

async function runConfirmedAction() {
  if (confirmModal.dangerous && confirmModal.text !== confirmModal.roleLabel) {
    confirmModal.error = 'Rollenname stimmt nicht überein.'
    return
  }
  if (confirmModal.mode === 'add') {
    await runAddMembers(confirmModal.userIds, confirmModal.roleTemplateId, {
      temporary: addTemporary.value,
      duration: temporaryDuration.value
    })
  } else {
    await runRemoveMember(confirmModal.userId, confirmModal.roleTemplateId)
  }
  confirmModal.show = false
}

async function runRemoveMember(userId, roleTemplateId) {
  busy.value = true
  await rolesStore.removeRoleMember({ roleTemplateId, userId })
  busy.value = false
}

async function runAddMembers(userIds, roleTemplateId, { temporary, duration } = {}) {
  const tid = roleTemplateId || selectedRole.value?.templateId
  const role = rolesStore.roles.find((r) => normalizeGuid(r.templateId) === normalizeGuid(tid))
  const isTemporary = !!(temporary ?? addTemporary.value)
  const durationValue = duration ?? temporaryDuration.value
  const durationMs = durationMsForValue(durationValue)
  resetPsCancel()
  busy.value = true
  let ok = 0
  let fail = 0
  const schedulePayload = []
  for (const uid of userIds) {
    if (psCancelRequested.value) break
    const r = await rolesStore.addRoleMember({ roleTemplateId: tid, userId: uid })
    if (r) {
      ok++
      if (isTemporary) {
        const u = usersStore.users.find((x) => normalizeGuid(x.id) === normalizeGuid(uid))
        schedulePayload.push({
          roleTemplateId: tid,
          roleLabel: role?.label || selectedRole.value?.label || '',
          userId: normalizeGuid(uid),
          userPrincipalName: u?.userPrincipalName || '',
          displayName: u?.displayName || '',
          durationMs
        })
      }
    } else fail++
  }
  if (schedulePayload.length) {
    await rolesStore.scheduleTemporaryAssignments(schedulePayload)
  }
  if (ok) addUserIds.value = []
  busy.value = false
}

onMounted(() => {
  rolesStore.fetchScheduledExpirations()
  if (!rolesStore.lastFetched) rolesStore.fetchManagedRoles()
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

.role-list-item {
  padding: 0.75rem 1rem;
  cursor: pointer;
  border-bottom: 1px solid var(--sidebar-border);
  transition: background 0.12s;
}
.role-list-item:hover {
  background: rgba(88, 166, 255, 0.06);
}
.role-list-item.active {
  background: rgba(88, 166, 255, 0.12);
  border-left: 3px solid #58a6ff;
  padding-left: calc(1rem - 3px);
}
.role-list-item:last-child {
  border-bottom: none;
}

.add-user-pick-list {
  max-height: 220px;
  overflow-y: auto;
  overflow-x: hidden;
  border: 1px solid #30363d;
  border-radius: 6px;
  background: rgba(0, 0, 0, 0.15);
}

.add-user-pick-row {
  cursor: pointer;
  margin: 0;
  border-bottom: 1px solid #21262d;
  transition: background 0.12s;
}

.add-user-pick-row:last-child {
  border-bottom: none;
}

.add-user-pick-row:hover {
  background: rgba(88, 166, 255, 0.06);
}

.add-user-pick-row.is-selected {
  background: rgba(88, 166, 255, 0.14);
  box-shadow: inset 3px 0 0 #58a6ff;
}

.add-user-pick-list .form-check-input {
  width: 1.05rem;
  height: 1.05rem;
  margin: 0;
  border-color: #58a6ff;
  background-color: #161b22;
}

.add-user-pick-list .form-check-input:checked {
  background-color: #58a6ff;
  border-color: #58a6ff;
}
</style>
