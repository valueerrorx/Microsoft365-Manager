// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

import { defineStore } from 'pinia'
import { useAuthStore } from './authStore'

let groupsDetailInflight = null

export const useGroupsStore = defineStore('groups', {
  state: () => ({
    groups: [],
    loading: false,
    error: null,
    lastFetched: null,
    lifecyclePolicy: null,
    lifecycleLoading: false,
    lifecyclePolicyGroupCount: null
  }),

  getters: {
    totalGroups: (state) => state.groups.length,
    teamsGroupsCount: (state) => state.groups.filter((g) => g.hasTeam === true).length
  },

  actions: {
    clearSession() {
      groupsDetailInflight = null
      this.$reset()
    },

    async fetchGroupsDetail() {
      if (groupsDetailInflight) return groupsDetailInflight
      const auth = useAuthStore()
      this.loading = true
      this.error = null
      auth.beginGraphOperation('Gruppen')
      groupsDetailInflight = (async () => {
        try {
          const result = await window.ipcRenderer.invoke('get-groups-detail')
          if (result.status === 'ok') {
            auth.markGraphConnected()
            this.groups = result.groups || []
            this.lastFetched = new Date()
            auth.addLog({ type: 'success', message: `${this.groups.length} Gruppen geladen` })
            auth.showToast(`${this.groups.length} Gruppen geladen`, 'success')
          } else {
            this.error = result.message
            this.groups = []
            auth.addLog({ type: 'error', message: result.message })
            auth.showToast(result.message, 'error')
          }
        } catch (e) {
          this.error = e.message
          this.groups = []
          auth.addLog({ type: 'error', message: e.message })
          auth.showToast(e.message, 'error')
        } finally {
          this.loading = false
          groupsDetailInflight = null
        }
      })()
      return groupsDetailInflight
    },

    async fetchGroupOwners(groupId) {
      const g = this.groups.find((x) => x.id === groupId)
      if (!g) return { status: 'error', ownerEmails: [] }
      if (g.ownersDetailLoaded) return { status: 'ok', ownerEmails: g.ownerEmails || [] }
      const result = await window.ipcRenderer.invoke('get-group-owners', { groupId })
      if (result.status === 'ok') {
        g.ownerEmails = result.ownerEmails || []
        g.ownersDetailLoaded = true
      }
      return result
    },

    async fetchGroupMembers(groupId) {
      return await window.ipcRenderer.invoke('get-group-members', { groupId })
    },

    async createGroup({ displayName, description, type, mailNickname, visibility, ownerUpns }) {
      const auth = useAuthStore()
      try {
        const result = await window.ipcRenderer.invoke('create-group', {
          displayName, description, type, mailNickname, visibility, ownerUpns
        })
        if (result.status === 'ok') {
          auth.showToast(result.message || 'Gruppe erstellt', 'success')
          await this.fetchGroupsDetail()
          return { ok: true, result }
        }
        auth.showToast(result.message || 'Fehler beim Erstellen', 'error')
        return { ok: false, result }
      } catch (e) {
        auth.showToast(e.message, 'error')
        return { ok: false, result: null }
      }
    },

    async updateGroup({ groupId, displayName, description }) {
      const auth = useAuthStore()
      try {
        const result = await window.ipcRenderer.invoke('update-group', { groupId, displayName, description })
        if (result.status === 'ok') {
          const g = this.groups.find((x) => x.id === groupId)
          if (g) {
            if (displayName !== undefined) g.displayName = displayName
            if (description !== undefined) g.description = description
          }
          auth.showToast('Gruppe aktualisiert', 'success')
          return true
        }
        auth.showToast(result.message, 'error')
        return false
      } catch (e) {
        auth.showToast(e.message, 'error')
        return false
      }
    },

    async deleteGroup(groupId) {
      const auth = useAuthStore()
      try {
        const result = await window.ipcRenderer.invoke('delete-group', { groupId })
        if (result.status === 'ok') {
          this.groups = this.groups.filter((g) => g.id !== groupId)
          auth.showToast('Gruppe gelöscht', 'success')
          return true
        }
        auth.showToast(result.message, 'error')
        return false
      } catch (e) {
        auth.showToast(e.message, 'error')
        return false
      }
    },

    // Batch delete via one PS script + Graph $batch (20 deletes per request).
    async deleteGroupsBatch(groupIds) {
      const auth = useAuthStore()
      const list = Array.isArray(groupIds) ? groupIds.filter(Boolean) : []
      if (!list.length) return { ok: 0, fail: 0 }
      auth.addLog?.({ type: 'info', message: `Batch-Löschen: ${list.length} Gruppen` })
      try {
        const result = await window.ipcRenderer.invoke('delete-groups', { groupIds: list })
        const deletedIds = Array.isArray(result.deletedGroupIds) ? result.deletedGroupIds : []
        const errors = Array.isArray(result.errors) ? result.errors : []
        if (deletedIds.length) {
          const del = new Set(deletedIds)
          this.groups = this.groups.filter((g) => !del.has(g.id))
        }
        for (const err of errors) {
          auth.addLog?.({ type: 'error', message: `${err.groupId}: ${err.message}` })
        }
        const ok = deletedIds.length
        const fail = errors.length
        const msg = result.message || `Gelöscht: ${ok}${fail ? `, fehlgeschlagen: ${fail}` : ''}`
        if (fail && !ok) auth.showToast(msg, 'error')
        else if (fail) auth.showToast(msg, 'warning')
        else auth.showToast(msg, 'success')
        return { ok, fail }
      } catch (e) {
        auth.showToast(e.message, 'error')
        return { ok: 0, fail: list.length }
      }
    },

    async removeGroupMember({ groupId, memberId }) {
      const auth = useAuthStore()
      try {
        const result = await window.ipcRenderer.invoke('remove-group-member', { groupId, memberId })
        if (result.status === 'ok') {
          auth.showToast('Mitglied entfernt', 'success')
          return true
        }
        auth.showToast(result.message, 'error')
        return false
      } catch (e) {
        auth.showToast(e.message, 'error')
        return false
      }
    },

    async addMembersToGroup({ groupId, userIds }) {
      const auth = useAuthStore()
      const result = await window.ipcRenderer.invoke('add-group-members', { groupId, userIds })
      if (result.status === 'error') {
        auth.showToast(result.message, 'error')
        return { ok: false, result }
      }
      const msg = result.message || 'Mitglieder aktualisiert'
      if (result.status === 'partial') auth.showToast(msg, 'warning')
      else auth.showToast(msg, 'success')
      return { ok: true, result }
    },

    async listLifecyclePoliciesForGroup(groupId) {
      const gid = String(groupId || '').trim()
      if (!gid) return { status: 'error', message: 'groupId fehlt', policies: [] }
      try {
        return await window.ipcRenderer.invoke('list-group-lifecycle-policies-for-group', { groupId: gid })
      } catch (e) {
        return { status: 'error', message: e.message, policies: [] }
      }
    },

    async fetchLifecyclePolicies() {
      const auth = useAuthStore()
      this.lifecycleLoading = true
      try {
        const result = await window.ipcRenderer.invoke('list-group-lifecycle-policies')
        if (result.status === 'ok') {
          const list = result.policies || []
          this.lifecyclePolicy = list[0] || null
        } else {
          this.lifecyclePolicy = null
          auth.addLog({ type: 'error', message: result.message })
          auth.showToast(result.message, 'error')
        }
      } catch (e) {
        this.lifecyclePolicy = null
        auth.showToast(e.message, 'error')
      } finally {
        this.lifecycleLoading = false
      }
    },

    refreshLifecyclePolicyGroupCount() {
      const p = this.lifecyclePolicy
      if (!p?.id) {
        this.lifecyclePolicyGroupCount = null
        return
      }
      const mgt = String(p.managedGroupTypes || '')
      const isM365Unified = (g) => Array.isArray(g?.groupTypes) && g.groupTypes.includes('Unified')
      if (mgt === 'All') {
        this.lifecyclePolicyGroupCount = this.groups.filter(isM365Unified).length
        return
      }
      if (mgt === 'None' || mgt === '') {
        this.lifecyclePolicyGroupCount = 0
        return
      }
      if (mgt === 'Selected') {
        // Graph exposes no cheap reverse list; M365 groups under selected policy typically have expirationDateTime set by the policy.
        this.lifecyclePolicyGroupCount = this.groups.filter((g) => isM365Unified(g) && g.expirationDateTime).length
        return
      }
      this.lifecyclePolicyGroupCount = null
    },

    async saveLifecyclePolicy({ policyId, groupLifetimeInDays, managedGroupTypes, alternateNotificationEmails }) {
      const auth = useAuthStore()
      try {
        const mode = policyId ? 'update' : 'create'
        const result = await window.ipcRenderer.invoke('save-group-lifecycle-policy', {
          mode,
          policyId,
          groupLifetimeInDays,
          managedGroupTypes,
          alternateNotificationEmails
        })
        if (result.status === 'ok' && result.policy) {
          this.lifecyclePolicy = result.policy
          auth.showToast(result.message || 'Ablaufrichtlinie gespeichert', 'success')
          return true
        }
        auth.showToast(result.message || 'Fehler', 'error')
        return false
      } catch (e) {
        auth.showToast(e.message, 'error')
        return false
      }
    },

    async addGroupsToLifecyclePolicy({ policyId, groupIds }) {
      const auth = useAuthStore()
      try {
        const result = await window.ipcRenderer.invoke('add-groups-to-lifecycle-policy', { policyId, groupIds })
        if (result.status === 'ok' || result.status === 'partial') {
          const msg = result.message || 'Gruppen zugeordnet'
          if (result.status === 'partial') auth.showToast(msg, 'warning')
          else auth.showToast(msg, 'success')
          await this.fetchGroupsDetail()
          return { ok: true, result }
        }
        auth.showToast(result.message || 'Zuordnung fehlgeschlagen', 'error')
        return { ok: false, result }
      } catch (e) {
        auth.showToast(e.message, 'error')
        return { ok: false, result: null }
      }
    },

    async removeGroupsFromLifecyclePolicy({ policyId, groupIds }) {
      const auth = useAuthStore()
      try {
        const result = await window.ipcRenderer.invoke('remove-groups-from-lifecycle-policy', { policyId, groupIds })
        if (result.status === 'ok' || result.status === 'partial') {
          const msg = result.message || 'Aus Ablaufrichtlinie entfernt'
          if (result.status === 'partial') auth.showToast(msg, 'warning')
          else auth.showToast(msg, 'success')
          await this.fetchGroupsDetail()
          return { ok: true, result }
        }
        auth.showToast(result.message || 'Entfernen fehlgeschlagen', 'error')
        return { ok: false, result }
      } catch (e) {
        auth.showToast(e.message, 'error')
        return { ok: false, result: null }
      }
    },

    // Laedt ein PowerShell-Script als Intune-Plattform-Script hoch und weist es der Gruppe zu.
    // scriptContent ist Klartext; wird hier Base64-kodiert (Intune-Anforderung). Gibt scriptId zurueck.
    async deployScriptToGroup({ groupId, displayName, scriptContent, fileName }) {
      const auth = useAuthStore()
      const gid = String(groupId || '').trim()
      const name = String(displayName || '').trim()
      const content = String(scriptContent || '')
      if (!gid || !name || !content.trim()) {
        auth.showToast('Gruppe, Name und Script-Inhalt erforderlich', 'error')
        return { ok: false, result: null }
      }
      const scriptContentBase64 = btoa(unescape(encodeURIComponent(content)))
      auth.addLog({ type: 'info', message: `Lade Intune-Script '${name}' hoch...` })
      try {
        const result = await window.ipcRenderer.invoke('deploy-intune-script', {
          groupId: gid,
          displayName: name,
          scriptContentBase64,
          fileName: fileName || 'script.ps1'
        })
        if (result.status === 'ok') {
          auth.addLog({ type: 'success', message: result.message })
          auth.showToast(result.message, 'success')
          return { ok: true, result }
        }
        auth.addLog({ type: 'error', message: result.message || 'Script-Deploy fehlgeschlagen' })
        auth.showToast(result.message || 'Script-Deploy fehlgeschlagen', 'error')
        return { ok: false, result }
      } catch (e) {
        auth.showToast(e.message, 'error')
        return { ok: false, result: null }
      }
    },

    // Liest die Ausfuehrungs-Zustaende eines zuvor deployten Intune-Scripts (pro Geraet).
    async fetchScriptRunStates(scriptId) {
      const sid = String(scriptId || '').trim()
      if (!sid) return { status: 'error', message: 'scriptId fehlt', states: [] }
      try {
        return await window.ipcRenderer.invoke('get-intune-script-runstates', { scriptId: sid })
      } catch (e) {
        return { status: 'error', message: e.message, states: [] }
      }
    }
  }
})
