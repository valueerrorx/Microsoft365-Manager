<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com> -->

<!-- Checkbox-Dropdown-Filter: Mehrfachauswahl + optionaler Invert-Modus.
     Invert + leere Auswahl = kein Filter. Invert + Auswahl = zeigt nur Einträge,
     die KEINER der gewählten Optionen entsprechen (NICHT A und NICHT B). -->
<template>
    <div class="msf" ref="root">
        <button type="button" class="form-select form-select-sm msf-toggle" :class="{ 'msf-active': modelValue.length }" @click="open = !open">
            <span class="msf-label">{{ buttonLabel }}</span>
        </button>
        <Teleport to="body">
        <div v-if="open" class="msf-menu" :style="menuStyle" ref="menu">
            <div v-if="searchable" class="msf-search">
                <input v-model="query" type="text" class="form-control form-control-sm" placeholder="Suchen…" />
            </div>
            <div class="msf-actions">
                <button type="button" class="btn btn-link btn-sm p-0" @click="clearAll">Alle</button>
                <button type="button" class="btn btn-link btn-sm p-0" @click="selectNone">Keine</button>
                <label class="msf-invert ms-auto" :style="{ color: invert ? '#d29922' : '#8b949e' }">
                    <input type="checkbox" class="form-check-input mt-0" :checked="invert" @change="onInvert($event.target.checked)" />
                    invertieren
                </label>
            </div>
            <div class="msf-list">
                <label v-for="o in visibleOptions" :key="o.value" class="msf-item">
                    <input type="checkbox" class="form-check-input mt-0" :checked="allMode || modelValue.includes(o.value)" @change="toggle(o.value)" />
                    <span>{{ o.label }}</span>
                </label>
                <div v-if="!visibleOptions.length" class="msf-empty">Keine Treffer</div>
            </div>
        </div>
        </Teleport>
    </div>
</template>

<script>
// Sentinel-Wert für "Keine ausgewählt": modelValue = [MSF_NONE] → Filter aktiv, matcht aber nichts.
// Parent-Filterblöcke müssen diesen Wert als "leere Treffermenge" behandeln.
export const MSF_NONE = '__msf_none__'
</script>

<script setup>
import { ref, computed, watch, nextTick, onMounted, onBeforeUnmount } from 'vue'

const props = defineProps({
    options: { type: Array, default: () => [] }, // [{ value, label }]
    modelValue: { type: Array, default: () => [] },
    invert: { type: Boolean, default: false },
    placeholder: { type: String, default: 'Alle' },
    searchable: { type: Boolean, default: false }
})
const emit = defineEmits(['update:modelValue', 'update:invert'])

const root = ref(null)
const menu = ref(null)
const open = ref(false)
const query = ref('')

// Menü ist nach <body> teleportiert (umgeht overflow-Clipping der Tabelle) → Position fix unter Button berechnen.
const menuStyle = ref({})
const positionMenu = () => {
    const r = root.value?.getBoundingClientRect()
    if (!r) return
    menuStyle.value = { position: 'fixed', top: `${r.bottom + 4}px`, left: `${r.left}px` }
}
watch(open, (v) => {
    if (v) nextTick(positionMenu)
})

const visibleOptions = computed(() => {
    const q = query.value.trim().toLowerCase()
    if (!q) return props.options
    return props.options.filter((o) => String(o.label).toLowerCase().includes(q))
})

// noneMode = "keine angehakt": modelValue = [MSF_NONE]. Filter aktiv, Parent zeigt nichts.
const noneMode = computed(() => props.modelValue.includes(MSF_NONE))
// Sichtbare (echte) Auswahl ohne Sentinel.
const selected = computed(() => props.modelValue.filter((v) => v !== MSF_NONE))

// Button-Text: leer (=alle) = placeholder; noneMode = "Keine"; sonst Labels mit "NICHT" bei invert.
const buttonLabel = computed(() => {
    if (noneMode.value) return 'Keine'
    if (!selected.value.length) return props.placeholder
    const labels = props.options.filter((o) => selected.value.includes(o.value)).map((o) => o.label)
    const txt = labels.length <= 2 ? labels.join(', ') : `${labels.length} ausgewählt`
    return props.invert ? `NICHT: ${txt}` : txt
})

// allMode (= alle Häkchen an) gilt nur bei leerer Auswahl OHNE noneMode.
const allMode = computed(() => !noneMode.value && !selected.value.length)

const toggle = (value) => {
    // Im allMode bedeutet Abwählen "alle außer diesem" → restliche Optionen explizit setzen.
    if (allMode.value) {
        emit('update:modelValue', props.options.map((o) => o.value).filter((v) => v !== value))
        return
    }
    // Im noneMode bedeutet Anhaken: nur dieser Wert (Sentinel raus).
    if (noneMode.value) {
        emit('update:modelValue', [value])
        return
    }
    const next = selected.value.includes(value)
        ? selected.value.filter((v) => v !== value)
        : [...selected.value, value]
    // Letzte Auswahl abgewählt → noneMode (nicht auto-alle).
    emit('update:modelValue', next.length ? next : [MSF_NONE])
}
// "Alle": alle Häkchen an (= leer, allMode).
const clearAll = () => emit('update:modelValue', [])
// "Keine": alle Häkchen aus (= Sentinel, noneMode).
const selectNone = () => emit('update:modelValue', [MSF_NONE])

// Invert auf allMode (leer): alle Werte materialisieren, sonst greift der Filter nicht (leer = kein Filter)
// → invert + alle ausgewählt = nichts sichtbar.
const onInvert = (checked) => {
    if (checked && allMode.value) emit('update:modelValue', props.options.map((o) => o.value))
    emit('update:invert', checked)
}

const onDocClick = (e) => {
    if (root.value?.contains(e.target) || menu.value?.contains(e.target)) return
    open.value = false
}
// Fixes Menü würde beim Scrollen wegdriften → äußeres Scrollen schließt; Scrollen IN der Liste nicht.
const onScroll = (e) => {
    if (!open.value) return
    if (menu.value?.contains(e.target)) return
    open.value = false
}
onMounted(() => {
    document.addEventListener('click', onDocClick)
    window.addEventListener('scroll', onScroll, true)
    window.addEventListener('resize', onScroll)
})
onBeforeUnmount(() => {
    document.removeEventListener('click', onDocClick)
    window.removeEventListener('scroll', onScroll, true)
    window.removeEventListener('resize', onScroll)
})
</script>

<style scoped>
.msf { position: relative; }
.msf-toggle { text-align: left; cursor: pointer; min-width: 160px; }
.msf-toggle.msf-active { border-color: #58a6ff; }
.msf-label { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
/* nach <body> teleportiert; Position kommt inline (position:fixed + top/left) */
.msf-menu {
    z-index: 2000; min-width: 220px; max-width: 320px;
    background: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 0.4rem;
    box-shadow: 0 6px 18px rgba(0,0,0,0.5);
}
.msf-search { margin-bottom: 0.4rem; }
.msf-actions { display: flex; align-items: center; gap: 0.75rem; margin-bottom: 0.35rem; font-size: 0.78rem; }
.msf-invert { display: inline-flex; align-items: center; gap: 0.3rem; cursor: pointer; margin-bottom: 0; }
.msf-list { max-height: 260px; overflow-y: auto; display: flex; flex-direction: column; gap: 0.15rem; }
.msf-item { display: flex; align-items: center; gap: 0.45rem; cursor: pointer; font-size: 0.82rem; padding: 0.15rem 0.2rem; border-radius: 4px; margin-bottom: 0; }
.msf-item:hover { background: #21262d; }
.msf-empty { font-size: 0.78rem; color: #8b949e; padding: 0.3rem 0.2rem; }
</style>
