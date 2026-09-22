// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

import { defineStore } from 'pinia'
import {
    normalizeUpnOrder,
    UPN_ORDER_GIVEN_FIRST
} from '../utils/upn.js'

const STORAGE_KEY = 'ms365.upnOrder'

function readStoredOrder() {
    try {
        return normalizeUpnOrder(localStorage.getItem(STORAGE_KEY))
    } catch {
        return UPN_ORDER_GIVEN_FIRST
    }
}

export const useUpnOrderStore = defineStore('upnOrder', {
    state: () => ({
        order: readStoredOrder()
    }),

    actions: {
        // Persist and broadcast UPN local-part order for create + remove matching.
        setOrder(order) {
            const next = normalizeUpnOrder(order)
            this.order = next
            try {
                localStorage.setItem(STORAGE_KEY, next)
            } catch {
                // ignore quota / private-mode failures
            }
        }
    }
})
