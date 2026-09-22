@memV1
RULE^upn^order^givenFirst|surnameFirst in upnOrderStore+localStorage ms365.upnOrder; default givenFirst; PS -UpnOrder
PATH^upn^helpers^src/utils/upn.js buildUpn(+order); create scripts/update-user-passwords.ps1
PATH^roles^whitelist^config/managed-directory-roles.json drives RolesView
