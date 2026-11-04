# Ysis SCIM Auth0 Migration

## Summary

Gerimedica is migrating the Ysis authentication platform from CAS to Auth0.  
This impacts all SCIM and SAML integrations.

The current authentication flow using:

```powershell
/cas/oauth/token
```

must be replaced with:

```powershell
/oauth/token
```

In addition, the OAuth request now requires the `audience` parameter.

Reference: Gerimedica migration notice (Acceptance 1).

---

# Required Changes

## 1. Add `AuthUrl` to Custom Connector Configuration

Add the following configuration object to the custom connector configuration:

```json
{
  "key": "AuthUrl",
  "type": "input",
  "defaultValue": "https://auth.acceptatie1.ysis.nl",
  "templateOptions": {
    "placeholder": "https://auth.acceptatie1.ysis.nl",
    "label": "AuthUrl",
    "description": "The URL to the Ysis authentication service.",
    "required": true
  }
}
```

---

# 2. Update Connector Configuration

## Old Situation

- `ClientID` contained the old SCIM client name
- Authentication used the CAS endpoint
- No `audience` parameter was required

## New Situation

- `ClientID` becomes the OAuth Client ID received from Gerimedica
- `ClientSecret` becomes the new OAuth secret received from Gerimedica
- `AuthUrl` must be configured

### Acceptance

```text
https://auth.acceptatie1.ysis.nl
```

### Production (expected)

```text
https://auth.ysis.nl
```

---

# 3. Update All Scripts Using Ysis Authentication

All scripts requesting OAuth tokens must be updated.

## Old Implementation

```powershell
$splatRequestToken = @{
    Uri    = "$($actionContext.Configuration.BaseUrl)/cas/oauth/token"
    Method = 'POST'
    Body   = @{
        client_id     = $($actionContext.Configuration.ClientID)
        client_secret = $($actionContext.Configuration.ClientSecret)
        scope         = 'scim'
        grant_type    = 'client_credentials'
    }
}

$responseAccessToken = Invoke-RestMethod @splatRequestToken -Verbose:$false
```

---

## New Implementation

```powershell
$splatRequestToken = @{
    Uri    = "$($actionContext.Configuration.AuthUrl)/oauth/token"
    Method = 'POST'
    Body   = @{
        client_id     = $($actionContext.Configuration.ClientID)
        client_secret = $($actionContext.Configuration.ClientSecret)
        scope         = 'scim'
        grant_type    = 'client_credentials'
        audience      = 'gerimedica-ext'
    }
}

$responseAccessToken = Invoke-RestMethod @splatRequestToken -Verbose:$false
```

---

# Important Changes

## Replace CAS endpoint

Replace:

```powershell
/cas/oauth/token
```

With:

```powershell
/oauth/token
```

---

## Add audience parameter

Add:

```powershell
audience = 'gerimedica-ext'
```

to every OAuth token request.

---

# Important Note

Some scripts use:

```powershell
$actionContext.Configuration
```

while others use:

```powershell
$config
```

Please keep the existing variable structure already used in the script to minimize risk and maintain consistency.

---

# Migration Notes

According to Gerimedica:

- CAS authentication will be decommissioned
- Auth0 authentication becomes mandatory
- SCIM integrations must use OAuth2 Client Credentials flow
- Required OAuth parameter:

```text
audience = gerimedica-ext
```

---

# Acceptance Criteria

- [ ] `AuthUrl` added to custom connector configuration
- [ ] OAuth token requests updated to `/oauth/token`
- [ ] `audience = gerimedica-ext` added
- [ ] All Ysis scripts updated
- [ ] Acceptance environment tested successfully
- [ ] Production configuration validated