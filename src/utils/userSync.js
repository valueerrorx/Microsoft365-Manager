// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

// Graph user is mastered by on-premises AD Connect (identity fields not writable in cloud).
export function isOnPremMasteredUser(user) {
  return user?.onPremisesSyncEnabled === true
}

// Profile fields that Microsoft Graph rejects for on-premises mastered users.
export const ON_PREM_LOCKED_PROFILE_FIELDS = ['givenName', 'surname', 'displayName']

// Short German explanation for the edit modal.
export function onPremSyncEditHint() {
  return 'Dieser Benutzer kommt aus dem lokalen Active Directory (Azure AD Connect). Vorname, Nachname und Anzeigename können nur dort geändert werden — Änderungen in Microsoft 365 werden abgelehnt und beim nächsten Sync überschrieben.'
}
