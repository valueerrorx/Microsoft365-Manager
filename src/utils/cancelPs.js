// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

import { ref } from 'vue'

// Globales Abbruch-Signal für laufende Aktionen.
// true => eine Abbruch-Anforderung läuft; JS-Batch-Schleifen prüfen das zwischen Iterationen.
export const psCancelRequested = ref(false)

// Bricht alle laufenden PowerShell-Aktionen ab: killt App-eigene pwsh-Prozessbäume (Main)
// und setzt das Abbruch-Flag, damit JS-Schleifen (Batch) zwischen Iterationen aussteigen.
// Wird von den Abbrechen-Buttons der Dialoge aufgerufen, während eine Aktion läuft.
export async function cancelRunningPs() {
    psCancelRequested.value = true
    try {
        await window.ipcRenderer.invoke('cancel-all-ps')
    } catch (e) {
        console.error('cancel-all-ps failed', e)
    }
}

// Vor jedem neuen Aktionslauf aufrufen, um ein altes Abbruch-Signal zu verwerfen.
export function resetPsCancel() {
    psCancelRequested.value = false
}
