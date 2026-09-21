// Builds a comma-separated CSV string from header + row arrays, quoting fields that need it (RFC 4180).
export function toCsv(header, rows) {
    const esc = (v) => {
        const s = v == null ? '' : String(v)
        return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
    }
    const lines = [header, ...rows].map((row) => row.map(esc).join(','))
    return lines.join('\r\n')
}

// UTF-8 BOM so Excel detects the encoding and renders Umlaute correctly.
export function csvBlob(csvString) {
    return new Blob(['﻿' + csvString], { type: 'text/csv;charset=utf-8;' })
}
