// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

import { defineStore } from 'pinia'
import { useAuthStore } from './authStore'

let rolesInflight = null

function normalizeGuid(value) {
  return String(value || '').trim().toLowerCase()
}

export const useRolesStore = defineStore('roles', {
  state: () => ({
    roles: [],
    loading: false,
    error: null,
    lastFetched: null,
    scheduledExpirations: []
  }),

  getters: {
    totalRoles: (state) => state.roles.length,
    roleByTemplateId: (state) => (templateId) =>
      state.roles.find((r) => r.templateId === templateId),

    scheduledForRole: (state) => (roleTemplateId) =>
      state.scheduledExpirations.filter((e) => e.roleTemplateId === roleTemplateId)
  },

  actions: {
    clearSession() {
      rolesInflight = null
      this.$reset()
    },

    async fetchScheduledExpirations() {
      try {
        const result = await window.ipcRenderer.invoke('get-scheduled-directory-role-expirations')
        if (result.status === 'ok') {
          this.scheduledExpirations = result.entries || []
          for (const role of this.roles) {
            this.syncScheduledExpirationsToMembers(role.templateId)
          }
        }
      } catch {
        this.scheduledExpirations = []
      }
    },

    expirationForMember(roleTemplateId, memberOrUserId) {
      const tid = normalizeGuid(roleTemplateId)
      if (!tid) return null
      const member =
        memberOrUserId && typeof memberOrUserId === 'object' ? memberOrUserId : null
      const uid = normalizeGuid(member?.id ?? memberOrUserId)
      const upn = String(
        member?.userPrincipalName || member?.mail || ''
      )
        .trim()
        .toLowerCase()
      return (
        this.scheduledExpirations.find((e) => {
          if (normalizeGuid(e.roleTemplateId) !== tid) return false
          if (uid && normalizeGuid(e.userId) === uid) return true
          if (upn && String(e.userPrincipalName || '').trim().toLowerCase() === upn) {
            return true
          }
          return false
        }) || null
      )
    },

    syncScheduledExpirationsToMembers(roleTemplateId) {
      const tid = normalizeGuid(roleTemplateId)
      if (!tid) return
      const role = this.roles.find((r) => normalizeGuid(r.templateId) === tid)
      if (!role?.members?.length) return
      role.members = role.members.map((m) => {
        const exp = this.expirationForMember(role.templateId, m)
        if (exp?.expiresAt) return { ...m, scheduledExpiresAt: exp.expiresAt }
        const { scheduledExpiresAt, ...rest } = m
        return rest
      })
    },

    async scheduleTemporaryAssignments(entries) {
      const auth = useAuthStore()
      const result = await window.ipcRenderer.invoke('schedule-temporary-directory-roles', { entries })
      if (result.status === 'ok') {
        this.scheduledExpirations = result.entries || []
        const scheduled = Number(result.scheduled) || 0
        if (entries.length && scheduled < entries.length) {
          auth.showToast(
            `Zeitplan nur teilweise gespeichert (${scheduled}/${entries.length})`,
            'warning'
          )
        } else if (entries.length && scheduled === 0) {
          auth.showToast('Zeitplan konnte nicht gespeichert werden (ungültige Daten)', 'error')
          return false
        }
        for (const entry of entries) {
          this.syncScheduledExpirationsToMembers(entry.roleTemplateId)
        }
        return true
      }
      auth.showToast(result.message || 'Zeitplan konnte nicht gespeichert werden', 'error')
      return false
    },

    async fetchManagedRoles() {
      if (rolesInflight) return rolesInflight
      const auth = useAuthStore()
      this.loading = true
      this.error = null
      auth.beginGraphOperation('Administratorenrollen')
      rolesInflight = (async () => {
        try {
          if (!auth.connected) {
            const conn = await window.ipcRenderer.invoke('ensure-graph-connected')
            if (conn?.status !== 'ok' && conn?.status !== 'partial') {
              this.error = conn?.message || 'Verbindung zu Microsoft Graph fehlgeschlagen.'
              auth.addLog({ type: 'error', message: this.error })
              auth.showToast(this.error, 'error')
              return
            }
            auth.markGraphConnected(conn.tenantDomain)
          }
          const result = await window.ipcRenderer.invoke('get-managed-directory-roles')
          if (result.status === 'ok' || result.status === 'partial') {
            auth.markGraphConnected()
            this.roles = result.roles || []
            this.lastFetched = new Date()
            const msg =
              result.status === 'partial'
                ? `${this.roles.length} Rollen geladen (teilweise Fehler)`
                : `${this.roles.length} Rollen geladen`
            auth.addLog({ type: result.status === 'partial' ? 'warning' : 'success', message: msg })
            auth.showToast(msg, result.status === 'partial' ? 'warning' : 'success')
            await this.fetchScheduledExpirations()
          } else {
            this.error = result.message
            this.roles = []
            auth.addLog({ type: 'error', message: result.message })
            auth.showToast(result.message, 'error')
          }
        } catch (e) {
          this.error = e.message
          this.roles = []
          auth.addLog({ type: 'error', message: e.message })
          auth.showToast(e.message, 'error')
        } finally {
          this.loading = false
          rolesInflight = null
        }
      })()
      return rolesInflight
    },

    async addRoleMember({ roleTemplateId, userId }) {
      const auth = useAuthStore()
      const result = await window.ipcRenderer.invoke('add-directory-role-member', { roleTemplateId, userId })
      if (result.status === 'ok') {
        const tid = normalizeGuid(roleTemplateId)
        const uid = normalizeGuid(userId)
        const role = this.roles.find((r) => normalizeGuid(r.templateId) === tid)
        if (role && !result.skipped) {
          const member = result.member
            ? {
                ...result.member,
                id: normalizeGuid(result.member.id || userId)
              }
            : { id: uid, userPrincipalName: '', displayName: '' }
          const exists = (role.members || []).some((m) => normalizeGuid(m.id) === uid)
          if (!exists) {
            role.members = [...(role.members || []), member]
            role.memberCount = role.members.length
          }
        }
        auth.showToast(result.message || 'Benutzer zur Rolle hinzugefügt', 'success')
        return true
      }
      auth.showToast(result.message, 'error')
      return false
    },

    async removeRoleMember({ roleTemplateId, userId }) {
      const auth = useAuthStore()
      const result = await window.ipcRenderer.invoke('remove-directory-role-member', { roleTemplateId, userId })
      if (result.status === 'ok') {
        const role = this.roles.find((r) => r.templateId === roleTemplateId)
        if (role) {
          role.members = (role.members || []).filter((m) => m.id !== userId)
          role.memberCount = role.members.length
        }
        await this.fetchScheduledExpirations()
        auth.showToast('Benutzer aus Rolle entfernt', 'success')
        return true
      }
      auth.showToast(result.message, 'error')
      return false
    }
  }
})
