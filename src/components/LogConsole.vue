<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com> -->

<template>
  <div class="log-console">
    <div
      v-show="expanded"
      class="log-console-resize-handle"
      title="Höhe ziehen"
      @mousedown.prevent="onResizeStart"
    />
    <div class="log-console-header">
      <div class="d-flex align-items-center gap-3">
        <i class="bi bi-terminal-fill" style="color:#58a6ff;font-size:0.8rem;"></i>
        <span
          class="log-tab"
          :class="{ active: activeTab === 'output' }"
          @click.stop="selectTab('output')"
        >Ausgabe<span v-if="authStore.logs.length" style="color:#484f58;"> ({{ authStore.logs.length }})</span></span>
        <span
          class="log-tab"
          :class="{ active: activeTab === 'powershell' }"
          @click.stop="selectTab('powershell')"
        >Graph PowerShell</span>
      </div>
      <div class="d-flex align-items-center gap-3">
        <span
          v-if="activeTab === 'output' && authStore.logs.length"
          @click.stop="authStore.clearLogs()"
          style="cursor:pointer;color:#484f58;font-size:0.72rem;"
          title="Löschen"
        >Leeren</span>
        <span
          v-if="activeTab === 'powershell'"
          @click.stop="bookmarksOpen = !bookmarksOpen"
          style="cursor:pointer;color:#484f58;font-size:0.72rem;"
          title="Gespeicherte Befehle"
        >Bookmarks<span v-if="bookmarks.length" style="color:#6e7681;"> ({{ bookmarks.length }})</span></span>
        <span
          v-if="activeTab === 'powershell'"
          @click.stop="resetConsole"
          style="cursor:pointer;color:#484f58;font-size:0.72rem;"
          title="Session neu starten"
        >Reset</span>
        <i
          class="bi"
          :class="expanded ? 'bi-chevron-down' : 'bi-chevron-up'"
          style="cursor:pointer;"
          @click.stop="expanded = !expanded"
        ></i>
      </div>
    </div>

    <!-- Ausgabe-Tab -->
    <div
      v-show="expanded && activeTab === 'output'"
      class="log-console-body"
      ref="logBody"
      :style="{ height: `${bodyHeightPx}px` }"
    >
      <div
        v-for="(log, i) in authStore.logs"
        :key="i"
        class="log-entry"
        :class="`log-${log.type || 'info'}`"
      >
        <span class="log-timestamp">{{ log.timestamp }}</span>{{ log.message }}
      </div>
      <div v-if="!authStore.logs.length" style="color:#484f58;font-size:0.75rem;">
        Noch keine Ausgaben...
      </div>
    </div>

    <!-- PowerShell-Tab -->
    <div v-show="expanded && activeTab === 'powershell'">
      <div
        v-if="bookmarksOpen"
        class="ps-bookmarks-panel"
        @click.stop
      >
        <div v-if="!bookmarks.length" class="ps-bookmarks-empty">Noch keine Bookmarks.</div>
        <div
          v-for="(bm, i) in bookmarks"
          :key="i"
          class="ps-bookmark-item"
        >
          <span class="ps-bookmark-text" :title="bm" @click="applyBookmark(bm)">{{ bm }}</span>
          <button
            type="button"
            class="ps-bookmark-remove"
            title="Bookmark entfernen"
            @click.stop="removeBookmark(i)"
          >
            <i class="bi bi-star-fill"></i>
            <i class="bi bi-dash-lg"></i>
          </button>
        </div>
      </div>
      <div
        class="log-console-body"
        ref="consoleBody"
        :style="{ height: `${bodyHeightPx}px` }"
      >
        <div
          v-for="(line, i) in consoleLines"
          :key="i"
          class="log-entry"
          :class="`log-${line.type || 'info'}`"
          style="white-space:pre-wrap;"
        >{{ line.text }}</div>
        <div v-if="!consoleLines.length" class="ps-examples">
          <div style="color:#8b949e;margin-bottom:6px;">Graph PowerShell — bereits mit Microsoft Graph verbunden. Befehl eingeben und Enter (↑/↓ = Verlauf).</div>
          <div class="ps-ex"># Verbindung / Tenant prüfen</div>
          <div class="ps-ex-cmd">Get-MgContext</div>
          <div class="ps-ex">&nbsp;</div>
          <div class="ps-ex"># Benutzer auflisten</div>
          <div class="ps-ex-cmd">Get-MgUser -Top 5 -Property DisplayName,UserPrincipalName | Format-Table DisplayName,UserPrincipalName</div>
          <div class="ps-ex">&nbsp;</div>
          <div class="ps-ex"># Einzelnen Benutzer holen</div>
          <div class="ps-ex-cmd">Get-MgUser -UserId "name@deinedomain.at" | Select DisplayName,UserPrincipalName,Id</div>
          <div class="ps-ex">&nbsp;</div>
          <div class="ps-ex"># Gruppen suchen</div>
          <div class="ps-ex-cmd">Get-MgGroup -Filter "startswith(DisplayName,'Lehrer')" | Format-Table DisplayName,Id</div>
          <div class="ps-ex">&nbsp;</div>
          <div class="ps-ex"># Gruppenmitglieder anzeigen</div>
          <div class="ps-ex-cmd">Get-MgGroupMember -GroupId "&lt;gruppen-id&gt;" | Select Id</div>
          <div class="ps-ex">&nbsp;</div>
          <div class="ps-ex"># Roher Graph-Request (jeder Endpoint)</div>
          <div class="ps-ex-cmd">Invoke-MgGraphRequest -Method GET -Uri "/v1.0/organization" -OutputType Hashtable</div>
          <div class="ps-ex">&nbsp;</div>
          <div class="ps-ex"># Lizenzen / SKUs im Tenant</div>
          <div class="ps-ex-cmd">Get-MgSubscribedSku | Select SkuPartNumber,ConsumedUnits</div>
        </div>
      </div>
      <div class="ps-input-row">
        <span class="ps-prompt">PS&gt;</span>
        <input
          v-model="consoleInput"
          class="ps-input"
          type="text"
          spellcheck="false"
          autocomplete="off"
          :disabled="consoleBusy"
          placeholder="Get-MgContext"
          @keydown.enter="sendCommand"
          @keydown.up.prevent="historyPrev"
          @keydown.down.prevent="historyNext"
        />
        <button
          type="button"
          class="ps-bookmark-add"
          title="Als Bookmark speichern"
          :disabled="!consoleInput.trim()"
          @click="addBookmark"
        >
          <i class="bi bi-star"></i>
          <i class="bi bi-plus-lg"></i>
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, nextTick, onMounted, onUnmounted } from 'vue'
import { useAuthStore } from '../stores/authStore'

const STORAGE_KEY = 'ms365-log-console-body-height'
const BOOKMARKS_KEY = 'ms365-graph-ps-bookmarks'
const DEFAULT_HEIGHT = 150
const MIN_HEIGHT = 64

const authStore = useAuthStore()
const expanded = ref(true)
const activeTab = ref('output')
const logBody = ref(null)
const bodyHeightPx = ref(DEFAULT_HEIGHT)

// PowerShell console state
const consoleLines = ref([])
const consoleInput = ref('')
const consoleBusy = ref(false)
const consoleBody = ref(null)
const history = ref([])
const historyIdx = ref(-1)
const bookmarks = ref([])
const bookmarksOpen = ref(false)

function selectTab(tab) {
  activeTab.value = tab
  expanded.value = true
}

function pushConsoleLine(type, text) {
  consoleLines.value.push({ type, text })
  scrollConsole()
}

async function scrollConsole() {
  await nextTick()
  if (consoleBody.value) consoleBody.value.scrollTop = consoleBody.value.scrollHeight
}

function sendCommand() {
  const cmd = consoleInput.value.trim()
  if (!cmd || consoleBusy.value) return
  history.value.push(cmd)
  historyIdx.value = history.value.length
  consoleInput.value = ''
  consoleBusy.value = true
  window.ipcRenderer.invoke('graph-console-exec', { command: cmd }).then((res) => {
    if (res?.status === 'error') {
      pushConsoleLine('error', `[${res.message}]\n`)
      consoleBusy.value = false
    }
  })
}

function historyPrev() {
  if (!history.value.length) return
  historyIdx.value = Math.max(0, historyIdx.value - 1)
  consoleInput.value = history.value[historyIdx.value] || ''
}

function historyNext() {
  if (!history.value.length) return
  historyIdx.value = Math.min(history.value.length, historyIdx.value + 1)
  consoleInput.value = history.value[historyIdx.value] || ''
}

function resetConsole() {
  window.ipcRenderer.invoke('graph-console-reset')
  consoleLines.value = []
  consoleBusy.value = false
}

// Persists bookmark list to localStorage.
function persistBookmarks() {
  try {
    localStorage.setItem(BOOKMARKS_KEY, JSON.stringify(bookmarks.value))
  } catch {}
}

// Adds current input as bookmark if not already saved.
function addBookmark() {
  const cmd = consoleInput.value.trim()
  if (!cmd || bookmarks.value.includes(cmd)) return
  bookmarks.value.push(cmd)
  persistBookmarks()
}

// Inserts bookmark into input and closes the panel.
function applyBookmark(cmd) {
  consoleInput.value = cmd
  historyIdx.value = history.value.length
  bookmarksOpen.value = false
}

// Removes bookmark at index and persists.
function removeBookmark(index) {
  bookmarks.value.splice(index, 1)
  persistBookmarks()
}

function onDocumentClick() {
  bookmarksOpen.value = false
}

// IPC listeners for streamed console output
function onConsoleOutput(_e, payload) {
  if (payload?.text) pushConsoleLine(payload.type || 'info', payload.text)
}
function onConsoleDone() {
  consoleBusy.value = false
}
function onConsoleExit() {
  consoleBusy.value = false
}

function maxBodyHeight() {
  return Math.max(MIN_HEIGHT, Math.floor(window.innerHeight * 0.82) - 140)
}

function clampBody(h) {
  return Math.min(Math.max(h, MIN_HEIGHT), maxBodyHeight())
}

let resizing = false
let startY = 0
let startH = 0

function onResizeStart(e) {
  resizing = true
  startY = e.clientY
  startH = bodyHeightPx.value
  window.addEventListener('mousemove', onResizeMove)
  window.addEventListener('mouseup', onResizeEnd)
  document.body.style.cursor = 'ns-resize'
  document.body.style.userSelect = 'none'
}

function onResizeMove(e) {
  if (!resizing) return
  bodyHeightPx.value = clampBody(startH + (startY - e.clientY))
}

function onResizeEnd() {
  resizing = false
  window.removeEventListener('mousemove', onResizeMove)
  window.removeEventListener('mouseup', onResizeEnd)
  document.body.style.cursor = ''
  document.body.style.userSelect = ''
  try {
    localStorage.setItem(STORAGE_KEY, String(bodyHeightPx.value))
  } catch {}
}

function onWindowResize() {
  bodyHeightPx.value = clampBody(bodyHeightPx.value)
}

onMounted(() => {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    const n = raw ? parseInt(raw, 10) : NaN
    bodyHeightPx.value = clampBody(Number.isFinite(n) ? n : DEFAULT_HEIGHT)
  } catch {
    bodyHeightPx.value = clampBody(DEFAULT_HEIGHT)
  }
  try {
    const raw = localStorage.getItem(BOOKMARKS_KEY)
    const parsed = raw ? JSON.parse(raw) : []
    bookmarks.value = Array.isArray(parsed) ? parsed.filter((s) => typeof s === 'string' && s.trim()) : []
  } catch {
    bookmarks.value = []
  }
  document.addEventListener('click', onDocumentClick)
  window.addEventListener('resize', onWindowResize)
  window.ipcRenderer.on('graph-console-output', onConsoleOutput)
  window.ipcRenderer.on('graph-console-done', onConsoleDone)
  window.ipcRenderer.on('graph-console-exit', onConsoleExit)
})

onUnmounted(() => {
  document.removeEventListener('click', onDocumentClick)
  window.removeEventListener('resize', onWindowResize)
  window.removeEventListener('mousemove', onResizeMove)
  window.removeEventListener('mouseup', onResizeEnd)
  window.ipcRenderer.removeListener('graph-console-output', onConsoleOutput)
  window.ipcRenderer.removeListener('graph-console-done', onConsoleDone)
  window.ipcRenderer.removeListener('graph-console-exit', onConsoleExit)
  document.body.style.cursor = ''
  document.body.style.userSelect = ''
})

watch(() => authStore.logs.length, async () => {
  if (activeTab.value !== 'output') {
    if (authStore.logs.length > 0) { /* keep current tab; badge updates */ }
    return
  }
  if (expanded.value) {
    await nextTick()
    if (logBody.value) logBody.value.scrollTop = logBody.value.scrollHeight
  } else if (authStore.logs.length > 0) {
    expanded.value = true
  }
})
</script>

<style scoped>
.log-tab {
  cursor: pointer;
  color: #8b949e;
  font-size: 0.78rem;
  padding-bottom: 2px;
  border-bottom: 2px solid transparent;
}
.log-tab.active {
  color: #c9d1d9;
  border-bottom-color: #58a6ff;
}
.ps-input-row {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px 8px;
  background: #0d1117;
  border-top: 1px solid #21262d;
}
.ps-prompt {
  color: #58a6ff;
  font-family: monospace;
  font-size: 0.78rem;
}
.ps-input {
  flex: 1;
  background: transparent;
  border: none;
  outline: none;
  color: #c9d1d9;
  font-family: monospace;
  font-size: 0.78rem;
}
.ps-input:disabled {
  opacity: 0.5;
}
.log-command {
  color: #58a6ff;
}
.ps-examples {
  font-family: monospace;
  font-size: 0.75rem;
  line-height: 1.5;
}
.ps-ex {
  color: #6e7681;
}
.ps-ex-cmd {
  color: #7ee787;
  white-space: pre-wrap;
}
.ps-bookmarks-panel {
  max-height: 160px;
  overflow-y: auto;
  background: #161b22;
  border-bottom: 1px solid #21262d;
  padding: 4px 0;
}
.ps-bookmarks-empty {
  color: #484f58;
  font-size: 0.72rem;
  padding: 6px 10px;
}
.ps-bookmark-item {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 3px 8px;
}
.ps-bookmark-item:hover {
  background: #21262d;
}
.ps-bookmark-text {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: #7ee787;
  font-family: monospace;
  font-size: 0.75rem;
  cursor: pointer;
}
.ps-bookmark-add,
.ps-bookmark-remove {
  position: relative;
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 22px;
  height: 22px;
  padding: 0;
  border: none;
  background: transparent;
  cursor: pointer;
}
.ps-bookmark-add:disabled {
  opacity: 0.35;
  cursor: default;
}
.ps-bookmark-add .bi-star {
  color: #8b949e;
  font-size: 0.95rem;
}
.ps-bookmark-add .bi-plus-lg {
  position: absolute;
  right: 0;
  bottom: 0;
  font-size: 0.55rem;
  color: #58a6ff;
  line-height: 1;
}
.ps-bookmark-remove .bi-star-fill {
  color: #d29922;
  font-size: 0.95rem;
}
.ps-bookmark-remove .bi-dash-lg {
  position: absolute;
  font-size: 0.7rem;
  color: #0d1117;
  font-weight: 700;
  line-height: 1;
}
.ps-bookmark-add:not(:disabled):hover .bi-star {
  color: #d29922;
}
</style>
