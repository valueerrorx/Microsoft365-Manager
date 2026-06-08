// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

import { defineStore } from 'pinia'
import { useAuthStore } from './authStore'

export const useBackupStore = defineStore('backup', {
  state: () => ({
    running: false,
    restoring: false
  }),

  actions: {
    clearSession() {
      this.$reset()
    },

    // Export the selected categories to a JSON file chosen via save dialog.
    async runBackup(categories) {
      const auth = useAuthStore()
      const cats = (categories || []).filter(Boolean)
      if (!cats.length) {
        auth.showToast('Mindestens eine Kategorie wählen', 'error')
        return false
      }
      this.running = true
      auth.beginGraphOperation('Backup')
      try {
        const result = await window.ipcRenderer.invoke('backup-tenant', { categories: cats })
        if (result.status === 'cancelled') {
          auth.addLog({ type: 'info', message: 'Backup abgebrochen' })
          return false
        }
        if (result.status === 'ok') {
          auth.markGraphConnected()
          auth.addLog({ type: 'success', message: `Backup gespeichert: ${result.filePath}` })
          auth.showToast('Backup gespeichert', 'success')
          return true
        }
        auth.addLog({ type: 'error', message: result.message })
        auth.showToast(result.message || 'Backup fehlgeschlagen', 'error')
        return false
      } catch (e) {
        auth.addLog({ type: 'error', message: e.message })
        auth.showToast(e.message, 'error')
        return false
      } finally {
        this.running = false
      }
    },

    // Open a backup JSON and return its preview (counts + meta) without restoring yet.
    async pickBackup() {
      const auth = useAuthStore()
      try {
        const result = await window.ipcRenderer.invoke('open-backup-dialog')
        if (result.status === 'cancelled') return null
        if (result.status === 'ok') return result
        auth.showToast(result.message || 'Datei konnte nicht gelesen werden', 'error')
        return null
      } catch (e) {
        auth.showToast(e.message, 'error')
        return null
      }
    },

    // Restore selected categories from the chosen backup file.
    async runRestore({ backupPath, categories, defaultPassword }) {
      const auth = useAuthStore()
      const cats = (categories || []).filter(Boolean)
      if (!backupPath || !cats.length) {
        auth.showToast('Datei und mindestens eine Kategorie wählen', 'error')
        return false
      }
      this.restoring = true
      auth.beginGraphOperation('Wiederherstellung')
      try {
        const result = await window.ipcRenderer.invoke('restore-tenant', { backupPath, categories: cats, defaultPassword })
        if (result.status === 'ok') {
          auth.markGraphConnected()
          auth.addLog({ type: 'success', message: result.message || 'Wiederherstellung abgeschlossen' })
          auth.showToast('Wiederherstellung abgeschlossen', 'success')
          return result
        }
        auth.addLog({ type: 'error', message: result.message })
        auth.showToast(result.message || 'Wiederherstellung fehlgeschlagen', 'error')
        return false
      } catch (e) {
        auth.addLog({ type: 'error', message: e.message })
        auth.showToast(e.message, 'error')
        return false
      } finally {
        this.restoring = false
      }
    }
  }
})
