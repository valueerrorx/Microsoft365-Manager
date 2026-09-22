<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com> -->

<template>
  <div class="d-inline-flex align-items-center flex-wrap gap-2" style="font-size:0.8rem;line-height:1.2;" role="radiogroup" aria-label="UPN-Reihenfolge">
    <span style="color:#8b949e;">UPN:</span>
    <label class="d-inline-flex align-items-center gap-1 mb-0" style="cursor:pointer;color:#e6edf3;">
      <input
        class="form-check-input mt-0"
        type="radio"
        :name="name"
        :value="UPN_ORDER_GIVEN_FIRST"
        :checked="upnOrderStore.order === UPN_ORDER_GIVEN_FIRST"
        style="width:14px;height:14px;flex:none;"
        @change="upnOrderStore.setOrder(UPN_ORDER_GIVEN_FIRST)"
      />
      <span style="font-family:monospace;">vorname.nachname</span>
    </label>
    <label class="d-inline-flex align-items-center gap-1 mb-0" style="cursor:pointer;color:#e6edf3;">
      <input
        class="form-check-input mt-0"
        type="radio"
        :name="name"
        :value="UPN_ORDER_SURNAME_FIRST"
        :checked="upnOrderStore.order === UPN_ORDER_SURNAME_FIRST"
        style="width:14px;height:14px;flex:none;"
        @change="upnOrderStore.setOrder(UPN_ORDER_SURNAME_FIRST)"
      />
      <span style="font-family:monospace;">nachname.vorname</span>
    </label>
  </div>
</template>

<script setup>
import { useUpnOrderStore } from '../stores/upnOrderStore'
import { UPN_ORDER_GIVEN_FIRST, UPN_ORDER_SURNAME_FIRST } from '../utils/upn.js'

defineProps({
  name: { type: String, default: 'upn-order' }
})

const upnOrderStore = useUpnOrderStore()
</script>
