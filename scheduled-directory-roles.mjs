// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

import fs from 'fs/promises'
import path from 'path'
import { randomUUID } from 'crypto'

const STORE_VERSION = 1
const TICK_MS = 60_000

function normalizeGuid(value) {
  return String(value || '').trim().toLowerCase()
}

export function createScheduledDirectoryRolesManager({
  app,
  runPsScript,
  parseJsonFromOutput,
  uiSend
}) {
  let graphSessionReady = false
  let intervalId = null
  let processing = false

  function getStorePath() {
    return path.join(app.getPath('userData'), 'scheduled-directory-role-expirations.json')
  }

  async function readStore() {
    try {
      const raw = await fs.readFile(getStorePath(), 'utf8')
      const parsed = JSON.parse(raw)
      if (!parsed || !Array.isArray(parsed.entries)) {
        return { version: STORE_VERSION, entries: [] }
      }
      return { version: STORE_VERSION, entries: parsed.entries }
    } catch (e) {
      if (e?.code === 'ENOENT') return { version: STORE_VERSION, entries: [] }
      return { version: STORE_VERSION, entries: [] }
    }
  }

  async function writeStore(store) {
    const filePath = getStorePath()
    await fs.mkdir(path.dirname(filePath), { recursive: true })
    const tmp = `${filePath}.${process.pid}.tmp`
    await fs.writeFile(tmp, JSON.stringify(store, null, 2), 'utf8')
    await fs.rename(tmp, filePath)
  }

  function notifyChanged(entries) {
    uiSend('scheduled-directory-roles-changed', { entries })
  }

  function setGraphSessionReady(ready) {
    const next = !!ready
    const was = graphSessionReady
    graphSessionReady = next
    if (next && !was) void processExpirations({ silent: true })
  }

  async function getEntries() {
    const store = await readStore()
    return store.entries
  }

  async function scheduleEntries(newEntries) {
    if (!Array.isArray(newEntries) || !newEntries.length) {
      return { status: 'ok', scheduled: 0, entries: await getEntries() }
    }
    const store = await readStore()
    const byKey = new Map()
    for (const e of store.entries) {
      byKey.set(`${normalizeGuid(e.roleTemplateId)}\0${normalizeGuid(e.userId)}`, e)
    }
    const now = new Date()
    let scheduled = 0
    for (const item of newEntries) {
      const roleTemplateId = normalizeGuid(item.roleTemplateId)
      const userId = normalizeGuid(item.userId)
      let durationMs = Number(item.durationMs)
      if (!Number.isFinite(durationMs) || durationMs <= 0) {
        const hours = Number(item.durationHours)
        if (Number.isFinite(hours) && hours > 0) durationMs = hours * 60 * 60 * 1000
      }
      if (!roleTemplateId || !userId || !Number.isFinite(durationMs) || durationMs <= 0) continue
      const expiresAt = new Date(now.getTime() + durationMs).toISOString()
      const key = `${roleTemplateId}\0${userId}`
      byKey.set(key, {
        id: randomUUID(),
        roleTemplateId,
        roleLabel: String(item.roleLabel || ''),
        userId,
        userPrincipalName: String(item.userPrincipalName || ''),
        displayName: String(item.displayName || ''),
        assignedAt: now.toISOString(),
        expiresAt,
        durationMs,
        lastError: null
      })
      scheduled++
    }
    store.entries = [...byKey.values()]
    await writeStore(store)
    notifyChanged(store.entries)
    if (graphSessionReady) void processExpirations({ silent: true })
    return { status: 'ok', scheduled, entries: store.entries }
  }

  async function cancelEntry(roleTemplateId, userId) {
    const tid = normalizeGuid(roleTemplateId)
    const uid = normalizeGuid(userId)
    if (!tid || !uid) return { status: 'ok', entries: await getEntries() }
    const store = await readStore()
    const before = store.entries.length
    store.entries = store.entries.filter(
      (e) => !(normalizeGuid(e.roleTemplateId) === tid && normalizeGuid(e.userId) === uid)
    )
    if (store.entries.length !== before) {
      await writeStore(store)
      notifyChanged(store.entries)
    }
    return { status: 'ok', entries: store.entries }
  }

  async function processExpirations({ silent = true } = {}) {
    if (!graphSessionReady || processing) return { processed: 0, removed: 0 }
    processing = true
    let removed = 0
    try {
      const store = await readStore()
      const now = Date.now()
      const expired = store.entries.filter((e) => {
        const t = new Date(e.expiresAt).getTime()
        return Number.isFinite(t) && t <= now
      })
      if (!expired.length) return { processed: 0, removed: 0 }

      let changed = false
      for (const entry of expired) {
        const result = await runPsScript(
          'scripts/remove-directory-role-member.ps1',
          ['-RoleTemplateId', entry.roleTemplateId, '-UserId', entry.userId],
          silent
            ? null
            : (log) => uiSend('ps-operation-log', log)
        )
        const data = parseJsonFromOutput(result.stdout)
        if (data?.status === 'ok') {
          store.entries = store.entries.filter((e) => e.id !== entry.id)
          removed++
          changed = true
          uiSend('directory-role-auto-removed', {
            roleTemplateId: entry.roleTemplateId,
            userId: entry.userId,
            roleLabel: entry.roleLabel
          })
          if (!silent) {
            uiSend('ps-operation-log', {
              type: 'success',
              message: `Temporäre Rolle entfernt: ${entry.displayName || entry.userPrincipalName} (${entry.roleLabel})`
            })
          }
        } else {
          const idx = store.entries.findIndex((e) => e.id === entry.id)
          if (idx >= 0) {
            store.entries[idx].lastError = data?.message || result.stderr || 'Unbekannter Fehler'
            changed = true
          }
        }
      }
      if (changed) {
        await writeStore(store)
        notifyChanged(store.entries)
      }
      return { processed: expired.length, removed }
    } finally {
      processing = false
    }
  }

  function startTicker() {
    if (intervalId) return
    intervalId = setInterval(() => {
      void processExpirations({ silent: true })
    }, TICK_MS)
  }

  function stopTicker() {
    if (intervalId) {
      clearInterval(intervalId)
      intervalId = null
    }
  }

  return {
    setGraphSessionReady,
    getEntries,
    scheduleEntries,
    cancelEntry,
    processExpirations,
    startTicker,
    stopTicker
  }
}
