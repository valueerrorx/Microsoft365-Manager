<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com> -->

<template>
  <nav class="app-sidebar" :class="{ collapsed: isCollapsed }">
    <!-- Brand -->
    <div class="sidebar-brand">
      <div class="sidebar-brand-row d-flex align-items-center gap-2">
        <img src="/icon.png" style="width:28px;border-radius:6px;flex-shrink:0;" alt="MS365 Manager" />
        <div class="sidebar-brand-text">
          <div style="font-size:0.875rem;line-height:1.2">MS365 Manager</div>
          <div style="font-size:0.68rem;color:#8b949e;font-weight:400">User Dashboard</div>
        </div>
        <button
          type="button"
          class="sidebar-toggle-btn"
          :title="isCollapsed ? 'Sidebar ausklappen' : 'Sidebar einklappen'"
          @click="toggleCollapsed"
        >
          <i class="bi" :class="isCollapsed ? 'bi-chevron-right' : 'bi-chevron-left'"></i>
        </button>
      </div>
    </div>

    <!-- Navigation -->
    <div class="flex-grow-1 pt-2">
      <div class="sidebar-section-label">Navigation</div>
      <RouterLink to="/" class="nav-link-custom" title="Dashboard">
        <i class="bi bi-speedometer2"></i>
        <span class="nav-label">Dashboard</span>
      </RouterLink>
      <RouterLink to="/users" class="nav-link-custom" title="Benutzerliste">
        <i class="bi bi-people"></i>
        <span class="nav-label">Benutzerliste</span>
        <span v-if="usersStore.users.length" class="nav-badge ms-auto" style="font-size:0.7rem;background:rgba(88,166,255,0.15);color:#58a6ff;border-radius:10px;padding:0.1rem 0.4rem;">
          {{ usersStore.users.length }}
        </span>
      </RouterLink>
      <RouterLink to="/groups" class="nav-link-custom" title="Gruppen">
        <i class="bi bi-collection"></i>
        <span class="nav-label">Gruppen</span>
        <span v-if="groupsStore.groups.length" class="nav-badge ms-auto" style="font-size:0.7rem;background:rgba(88,166,255,0.15);color:#58a6ff;border-radius:10px;padding:0.1rem 0.4rem;">
          {{ groupsStore.groups.length }}
        </span>
      </RouterLink>
      <RouterLink to="/devices" class="nav-link-custom" title="Geräte">
        <i class="bi bi-pc-display"></i>
        <span class="nav-label">Geräte</span>
        <span v-if="devicesStore.devices.length" class="nav-badge ms-auto" style="font-size:0.7rem;background:rgba(88,166,255,0.15);color:#58a6ff;border-radius:10px;padding:0.1rem 0.4rem;">
          {{ devicesStore.devices.length }}
        </span>
      </RouterLink>
      <RouterLink to="/roles" class="nav-link-custom" title="Rollen">
        <i class="bi bi-shield-lock"></i>
        <span class="nav-label">Rollen</span>
        <span v-if="rolesStore.roles.length" class="nav-badge ms-auto" style="font-size:0.7rem;background:rgba(88,166,255,0.15);color:#58a6ff;border-radius:10px;padding:0.1rem 0.4rem;">
          {{ rolesStore.roles.length }}
        </span>
      </RouterLink>

      <div class="sidebar-section-label mt-2">Aktionen</div>
      <RouterLink to="/create" class="nav-link-custom" title="Erstellen / Import">
        <i class="bi bi-person-plus"></i>
        <span class="nav-label">Erstellen / Import</span>
      </RouterLink>
      <RouterLink to="/remove" class="nav-link-custom" title="CSV Batch-Verwaltung">
        <i class="bi bi-person-dash"></i>
        <span class="nav-label">Batch / CSV</span>
      </RouterLink>
      <RouterLink to="/remove-devices" class="nav-link-custom" title="Geräte entfernen / CSV">
        <i class="bi bi-pc-display"></i>
        <span class="nav-label">Geräte entfernen / CSV</span>
      </RouterLink>
      <RouterLink to="/create-group" class="nav-link-custom" title="Gruppe erstellen">
        <i class="bi bi-collection"></i>
        <span class="nav-label">Gruppe erstellen</span>
      </RouterLink>
      <RouterLink to="/backup" class="nav-link-custom" title="Backup / Wiederherstellen">
        <i class="bi bi-archive"></i>
        <span class="nav-label">Backup</span>
      </RouterLink>
    </div>

    <!-- Connection + version (pinned bottom) -->
    <div class="sidebar-footer mt-auto">
      <div style="padding:0.75rem 1rem;border-top:1px solid var(--sidebar-border);">
        <button
          type="button"
          class="sidebar-domain-btn d-flex align-items-center gap-2 mb-2"
          :class="{ 'justify-content-center': isCollapsed }"
          :disabled="!authStore.connected"
          :title="authStore.connected ? `Aktive Domain: ${authStore.tenantDomain} — klicken zum Wechseln` : 'Nicht verbunden'"
          @click="openDomainPicker"
        >
          <div
            class="conn-dot"
            :class="authStore.connected ? 'connected' : 'disconnected'"
          ></div>
          <span class="sidebar-footer-detail" style="font-size:0.78rem;color:var(--text-secondary);">
            {{ authStore.connected ? authStore.tenantDomain : 'Nicht verbunden' }}
          </span>
          <i
            v-if="authStore.connected && !isCollapsed"
            class="bi bi-chevron-expand sidebar-footer-detail"
            style="font-size:0.7rem;color:var(--text-secondary);margin-left:auto;"
          ></i>
        </button>
        <div v-if="usersStore.lastFetched" class="sidebar-footer-detail" style="font-size:0.7rem;color:var(--text-secondary);margin-bottom:0.4rem;">
          Zuletzt: {{ formatTime(usersStore.lastFetched) }}
        </div>
        <button
          type="button"
          class="sidebar-logout-btn"
          :disabled="!canLogout || authStore.loggingOut"
          :title="authStore.loggingOut ? 'Melde ab…' : 'Abmelden'"
          @click="handleLogout"
        >
          <i class="bi bi-box-arrow-left"></i>
          <span class="btn-label">{{ authStore.loggingOut ? 'Melde ab…' : 'Abmelden' }}</span>
        </button>
        <button type="button" class="sidebar-quit-btn mt-2" title="Programm schliessen" @click="handleQuit">
          <i class="bi bi-power"></i>
          <span class="btn-label">Programm schliessen</span>
        </button>
      </div>
      <button
        type="button"
        class="sidebar-version-btn"
        :title="'Version ' + appVersion"
        @click="aboutModalOpen = true"
      >
        v{{ appVersion }}
      </button>
    </div>

    <div
      v-if="domainModalOpen"
      class="modal d-block about-modal-backdrop"
      tabindex="-1"
      @click.self="domainModalOpen = false"
    >
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content about-modal-content">
          <div class="modal-header" style="border-bottom:1px solid var(--sidebar-border);">
            <h5 class="modal-title" style="font-size:1rem;">
              <i class="bi bi-globe2 me-2" style="color:#58a6ff;"></i> Aktive Domain
            </h5>
            <button type="button" class="btn-close btn-close-white" @click="domainModalOpen = false"></button>
          </div>
          <div class="modal-body">
            <p style="font-size:0.82rem;color:var(--text-secondary);">
              Neue Benutzer werden mit dieser Domain angelegt.
            </p>
            <div v-if="authStore.domainsLoading" style="font-size:0.85rem;color:var(--text-secondary);">
              <i class="bi bi-arrow-repeat spin me-1"></i> Domains werden geladen…
            </div>
            <div v-else-if="!authStore.tenantDomains.length" style="font-size:0.85rem;color:var(--text-secondary);">
              Keine Domains geladen.
            </div>
            <div v-else class="d-flex flex-column gap-1">
              <button
                v-for="d in authStore.tenantDomains"
                :key="d.name"
                type="button"
                class="domain-option d-flex align-items-center gap-2"
                :class="{ active: d.name === authStore.tenantDomain }"
                @click="chooseDomain(d.name)"
              >
                <i
                  class="bi"
                  :class="d.name === authStore.tenantDomain ? 'bi-check-circle-fill' : 'bi-circle'"
                  :style="{ color: d.name === authStore.tenantDomain ? '#3fb950' : '#8b949e' }"
                ></i>
                <span style="font-family:monospace;font-size:0.82rem;">{{ d.name }}</span>
                <span v-if="d.isDefault" class="domain-badge">Standard</span>
                <span v-if="d.isInitial" class="domain-badge">onmicrosoft</span>
              </button>
            </div>
          </div>
          <div class="modal-footer" style="border-top:1px solid var(--sidebar-border);">
            <button
              type="button"
              class="btn btn-sm btn-outline-secondary"
              :disabled="authStore.domainsLoading"
              @click="authStore.fetchTenantDomains()"
            >
              <i class="bi bi-arrow-clockwise me-1"></i> Aktualisieren
            </button>
          </div>
        </div>
      </div>
    </div>

    <div
      v-if="aboutModalOpen"
      class="modal d-block about-modal-backdrop"
      tabindex="-1"
      @click.self="aboutModalOpen = false"
    >
      <div class="modal-dialog modal-dialog-centered modal-sm">
        <div class="modal-content about-modal-content">
          <div class="modal-body text-center py-4 px-3">
            <div class="copyleft-glyph" aria-hidden="true">©</div>
            <p class="mt-1 mb-1 text-secondary small">2026</p>
            <p class="mb-0 mt-2 fw-semibold" style="color:var(--text-primary);font-size:1.05rem;">{{ appDisplayName }}</p>
            <p class="mb-0 mt-1 fw-normal" style="color:var(--text-secondary);font-size:0.82rem;">{{ appVersionFull }}</p>
            <p class="mb-0 mt-4 fw-normal" style="color:var(--text-primary);font-size:1.08rem;">Thomas Michael Weissel</p>
            <p class="mb-0 mt-3">
              <button type="button" class="about-vendor-link" @click="openXapientSite">https://xapient.solutions/</button>
            </p>
          </div>
        </div>
      </div>
    </div>
  </nav>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'

const SIDEBAR_COLLAPSED_KEY = 'ms365-sidebar-collapsed'
import { useAuthStore } from '../stores/authStore'
import { useUsersStore } from '../stores/usersStore'
import { useGroupsStore } from '../stores/groupsStore'
import { useDevicesStore } from '../stores/devicesStore'
import { useRolesStore } from '../stores/rolesStore'
import pkg from '../../package.json'

const appDisplayName = 'MS365 Manager'
const appVersion = pkg.version
const appVersionFull = `Version ${pkg.version}`
const xapientUrl = 'https://xapient.solutions/'
const aboutModalOpen = ref(false)
const domainModalOpen = ref(false)
const isCollapsed = ref(false)

// Toggle sidebar width and persist preference in localStorage.
function toggleCollapsed() {
  isCollapsed.value = !isCollapsed.value
  try {
    localStorage.setItem(SIDEBAR_COLLAPSED_KEY, isCollapsed.value ? '1' : '0')
  } catch {}
}

onMounted(() => {
  try {
    isCollapsed.value = localStorage.getItem(SIDEBAR_COLLAPSED_KEY) === '1'
  } catch {}
})

const authStore = useAuthStore()
const usersStore = useUsersStore()
const groupsStore = useGroupsStore()
const devicesStore = useDevicesStore()
const rolesStore = useRolesStore()

const canLogout = computed(
  () =>
    authStore.connected ||
    !!usersStore.lastFetched ||
    !!groupsStore.lastFetched ||
    !!devicesStore.lastFetched ||
    !!rolesStore.lastFetched
)

// Opens the domain picker; loads the tenant's verified domains on first use.
async function openDomainPicker() {
  if (!authStore.connected) return
  domainModalOpen.value = true
  if (!authStore.tenantDomains.length) await authStore.fetchTenantDomains()
}

async function chooseDomain(name) {
  if (name === authStore.tenantDomain) {
    domainModalOpen.value = false
    return
  }
  const ok = await authStore.setActiveDomain(name)
  if (ok) domainModalOpen.value = false
}

function formatTime(date) {
  return date.toLocaleTimeString('de-AT', { hour: '2-digit', minute: '2-digit' })
}

function handleLogout() {
  if (!canLogout.value) return
  void authStore.logout()
}

function handleQuit() {
  void window.ipcRenderer.invoke('request-app-close')
}

async function openXapientSite() {
  try {
    const r = await window.ipcRenderer.invoke('open-external-url', xapientUrl)
    if (!r?.ok) authStore.showToast('Link konnte nicht geöffnet werden.', 'error')
  } catch {
    authStore.showToast('Link konnte nicht geöffnet werden.', 'error')
  }
}
</script>

<style scoped>
.sidebar-footer {
  flex-shrink: 0;
}

.sidebar-logout-btn {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  width: 100%;
  padding: 0.4rem 0.55rem;
  border: 1px solid rgba(248, 81, 73, 0.35);
  border-radius: 6px;
  background: rgba(248, 81, 73, 0.08);
  color: #f85149;
  font-size: 0.78rem;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s, color 0.15s;
}

.sidebar-logout-btn:hover:not(:disabled) {
  background: rgba(248, 81, 73, 0.16);
  border-color: rgba(248, 81, 73, 0.55);
  color: #ff7b72;
}

.sidebar-logout-btn:disabled {
  opacity: 0.6;
  cursor: default;
}

.sidebar-quit-btn {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  width: 100%;
  padding: 0.4rem 0.55rem;
  border: 1px solid var(--sidebar-border);
  border-radius: 6px;
  background: rgba(255, 255, 255, 0.04);
  color: var(--text-secondary);
  font-size: 0.78rem;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s, color 0.15s;
}

.sidebar-quit-btn:hover {
  background: rgba(255, 255, 255, 0.08);
  border-color: #484f58;
  color: var(--text-primary);
}

.sidebar-version-btn {
  display: block;
  width: 100%;
  padding: 0.35rem 1rem 0.65rem;
  border: 0;
  background: transparent;
  text-align: left;
  font-size: 0.68rem;
  color: #6e7681;
  cursor: pointer;
  transition: color 0.15s, background 0.15s;
}

.sidebar-version-btn:hover {
  color: #8b949e;
  background: rgba(255, 255, 255, 0.04);
}

.sidebar-domain-btn {
  width: 100%;
  background: none;
  border: none;
  padding: 0;
  text-align: left;
}

.sidebar-domain-btn:hover:not(:disabled) .sidebar-footer-detail {
  color: var(--text-primary) !important;
}

.sidebar-domain-btn:disabled {
  cursor: default;
}

.domain-option {
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--sidebar-border);
  border-radius: 6px;
  padding: 0.5rem 0.7rem;
  color: var(--text-primary);
  text-align: left;
}

.domain-option:hover {
  background: rgba(88, 166, 255, 0.1);
}

.domain-option.active {
  border-color: rgba(63, 185, 80, 0.5);
}

.domain-badge {
  font-size: 0.68rem;
  color: #8b949e;
  border: 1px solid var(--sidebar-border);
  border-radius: 10px;
  padding: 0 0.45rem;
}

.spin { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.about-modal-backdrop {
  background: rgba(0, 0, 0, 0.6);
}

.about-modal-content {
  background: #21262d;
  border: 1px solid var(--sidebar-border);
  color: var(--text-primary);
}

.copyleft-glyph {
  font-size: 3.25rem;
  line-height: 1;
  display: inline-block;
  transform: scaleX(-1);
  color: #e6edf3;
  font-weight: 400;
  user-select: none;
}

.about-vendor-link {
  color: #58a6ff;
  text-decoration: none;
  font-size: 0.9rem;
  word-break: break-all;
  background: none;
  border: 0;
  padding: 0;
  cursor: pointer;
  text-align: center;
}

.about-vendor-link:hover {
  color: #79b8ff;
  text-decoration: underline;
}
</style>
