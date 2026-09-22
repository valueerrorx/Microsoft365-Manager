// SPDX-License-Identifier: GPL-3.0-or-later
// Quick assert script for UPN order helpers (no test runner in repo).
import {
    buildUpn,
    buildUpnLocal,
    normalizeUpnOrder,
    UPN_ORDER_GIVEN_FIRST,
    UPN_ORDER_SURNAME_FIRST
} from '../src/utils/upn.js'

function assert(cond, msg) {
    if (!cond) throw new Error(msg)
}

assert(normalizeUpnOrder('nope') === UPN_ORDER_GIVEN_FIRST, 'default coerce')
assert(buildUpnLocal('max', 'mustermann', UPN_ORDER_GIVEN_FIRST) === 'max.mustermann', 'given local')
assert(buildUpnLocal('max', 'mustermann', UPN_ORDER_SURNAME_FIRST) === 'mustermann.max', 'surname local')
assert(buildUpn('Max', 'Müller', 'schule.at', UPN_ORDER_GIVEN_FIRST) === 'max.mueller@schule.at', 'given upn')
assert(buildUpn('Max', 'Müller', 'schule.at', UPN_ORDER_SURNAME_FIRST) === 'mueller.max@schule.at', 'surname upn')
console.log('check-upn-order: ok')
