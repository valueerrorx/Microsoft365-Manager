// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) Mag. Thomas Michael Weissel <valueerror@gmail.com>

export async function resetAllDataStores() {
  const [{ useUsersStore }, { useGroupsStore }, { useDevicesStore }, { useRolesStore }] = await Promise.all([
    import('./usersStore.js'),
    import('./groupsStore.js'),
    import('./devicesStore.js'),
    import('./rolesStore.js')
  ])
  useUsersStore().clearSession()
  useGroupsStore().clearSession()
  useDevicesStore().clearSession()
  useRolesStore().clearSession()
}
