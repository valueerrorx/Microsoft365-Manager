// Copies unique UPNs semicolon-separated to the clipboard.
export async function copyUpnsToClipboard(upns, showToast) {
    const list = [...new Set(
        (Array.isArray(upns) ? upns : []).map((e) => String(e || '').trim()).filter(Boolean)
    )]
    if (!list.length) {
        showToast('Keine UPNs in der Auswahl.', 'warning')
        return false
    }
    try {
        await navigator.clipboard.writeText(list.join(';'))
        showToast(`${list.length} UPN${list.length === 1 ? '' : 's'} kopiert.`, 'success')
        return true
    } catch {
        showToast('Zwischenablage nicht verfügbar.', 'error')
        return false
    }
}
