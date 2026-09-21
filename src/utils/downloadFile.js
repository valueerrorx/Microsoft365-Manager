// Triggers a save for a Blob, since <a download> on file:// (Electron) doesn't trigger a save.
export function downloadBlob(blob, filename) {
    const blobUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = blobUrl
    a.download = filename
    document.body.appendChild(a)
    a.click()
    a.remove()
    URL.revokeObjectURL(blobUrl)
}

// Downloads a local asset URL as a file via Blob.
export async function downloadSampleCsv(url, filename) {
    const res = await fetch(url)
    const blob = await res.blob()
    downloadBlob(blob, filename)
}
