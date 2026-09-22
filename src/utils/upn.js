// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

export const UPN_ORDER_GIVEN_FIRST = 'givenFirst'
export const UPN_ORDER_SURNAME_FIRST = 'surnameFirst'

// Coerce unknown/empty values to the app default (givenFirst).
export function normalizeUpnOrder(order) {
    return order === UPN_ORDER_SURNAME_FIRST ? UPN_ORDER_SURNAME_FIRST : UPN_ORDER_GIVEN_FIRST
}

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

// Build local-part from normalized given/surname according to order.
export function buildUpnLocal(vornameNormalized, nachnameNormalized, order = UPN_ORDER_GIVEN_FIRST) {
    const vn = String(vornameNormalized || '').toLowerCase()
    const nn = String(nachnameNormalized || '').toLowerCase()
    if (!vn || !nn) return ''
    return normalizeUpnOrder(order) === UPN_ORDER_SURNAME_FIRST ? `${nn}.${vn}` : `${vn}.${nn}`
}

// Build the UPN: order selects vorname.nachname vs nachname.vorname before @domain.
export function buildUpn(vorname, nachname, domain, order = UPN_ORDER_GIVEN_FIRST) {
    const local = buildUpnLocal(normalizeForUPN(vorname), normalizeForUPN(nachname), order)
    if (!local || !domain) return ''
    return `${local}@${domain}`
}

// Match CSV names against loaded users: prefer full UPN@domain, else unique local-part.
export function resolveUpnForEntry(entry, domain, users, order = UPN_ORDER_GIVEN_FIRST) {
    const vn = normalizeForUPN(entry?.vorname)
    const nn = normalizeForUPN(entry?.nachname)
    if (!vn || !nn) return { upn: '', count: 0 }
    const local = buildUpnLocal(vn, nn, order)
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
