// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

// Normalize a name part for use in a UPN (umlauts/diacritics -> ascii, strip rest).
// Must stay identical to normalizeForUPN() in index.js so create & remove build the same UPN.
export function normalizeForUPN(text) {
    if (!text) return ''
    let s = String(text)
    s = s.replace(/[äÄ]/g, 'ae').replace(/[öÖ]/g, 'oe').replace(/[üÜ]/g, 'ue').replace(/[ß]/g, 'ss')
    s = s.replace(/[àáâãăÀÁÂÃĂ]/g, 'a').replace(/[èéêëÈÉÊË]/g, 'e').replace(/[ìíîïÌÍÎÏ]/g, 'i')
    s = s.replace(/[òóôõÒÓÔÕ]/g, 'o').replace(/[ùúûÙÚÛ]/g, 'u').replace(/[ýÿȳÝŸȲ]/g, 'y')
    s = s.replace(/[çćčÇĆČ]/g, 'c').replace(/[ñÑ]/g, 'n')
    s = s.replace(/[žŽ]/g, 'z').replace(/[šŠ]/g, 's').replace(/[đĐ]/g, 'd')
    // Generic fallback for any remaining accented latin letters (ș, ț, î, ...):
    // decompose and strip combining marks. Runs after the explicit ä->ae etc. rules.
    s = s.normalize('NFD').replace(/[̀-ͯ]/g, '')
    return s.toLowerCase().replace(/[^a-z0-9.]/g, '')
}

// Build the UPN exactly as the create flow does: nachname.vorname@domain.
export function buildUpn(vorname, nachname, domain) {
    const vn = normalizeForUPN(vorname)
    const nn = normalizeForUPN(nachname)
    if (!vn || !nn || !domain) return ''
    return `${nn}.${vn}@${domain}`
}

// Match CSV names against loaded users: prefer full UPN@domain, else unique local-part (nachname.vorname).
export function resolveUpnForEntry(entry, domain, users) {
    const vn = normalizeForUPN(entry?.vorname)
    const nn = normalizeForUPN(entry?.nachname)
    if (!vn || !nn) return { upn: '', count: 0 }
    const local = `${nn}.${vn}`.toLowerCase()
    const built = domain ? `${local}@${String(domain).toLowerCase()}` : ''
    const list = Array.isArray(users) ? users : []
    const byLocal = list.filter((u) => {
        const upn = String(u.userPrincipalName || '').toLowerCase()
        const at = upn.indexOf('@')
        return at > 0 && upn.slice(0, at) === local
    })
    if (built) {
        const exact = byLocal.filter((u) => String(u.userPrincipalName || '').toLowerCase() === built)
        if (exact.length === 1) return { upn: exact[0].userPrincipalName, count: 1 }
        if (exact.length > 1) return { upn: built, count: exact.length }
    }
    if (byLocal.length === 1) return { upn: byLocal[0].userPrincipalName, count: 1 }
    if (byLocal.length > 1) return { upn: byLocal[0].userPrincipalName, count: byLocal.length }
    return { upn: built || '', count: 0 }
}
