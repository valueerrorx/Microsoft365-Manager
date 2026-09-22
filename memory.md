@memV1
RULE^upn^order^givenFirst|surnameFirst in upnOrderStore+localStorage ms365.upnOrder; default givenFirst; PS -UpnOrder
PATH^upn^helpers^src/utils/upn.js buildUpn(+order); create scripts/update-user-passwords.ps1
PATH^roles^whitelist^config/managed-directory-roles.json drives RolesView
RULE^license^explicit^create flow passes -LicenseSkuId from UI dropdown; PS no longer guesses A3 SKU by name
PATH^license^skus^usersStore.licenses via IPC get-licenses (scripts/get-ms365-licenses.ps1); labels src/utils/licenseLabel.js
RULE^domain^active^active domain = tenant default VerifiedDomain; resolved in ensure-graph-connection.ps1, cached userData/tenant-domain.json as lastKnownTenantDomain, passed to update-user-passwords.ps1 -TenantDomain
IPC^domain^list^get-tenant-domains -> scripts/get-tenant-domains.ps1 {domains[{name,isDefault,isInitial,type}],defaultDomain}
IPC^domain^pick^set-active-domain pins domain in userData/tenant-domain.json; pinned wins over script tenantDomain in onGraphResponse
