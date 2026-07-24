# HelloID-Conn-Prov-Target-Ysis

> [!WARNING]
> **Version 3.0.0 introduces a breaking change in the authentication method with Ysis.**  
> The authentication is migrated from CAS to Auth0.

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Ysis/blob/main/Logo.png?raw=true">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-Ysis](#helloid-conn-prov-target-ysis)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Supported features](#supported-features)
  - [Getting started](#getting-started)
    - [HelloID Icon URL](#helloid-icon-url)
    - [Requirements](#requirements)
    - [Connection settings](#connection-settings)
    - [Correlation configuration](#correlation-configuration)
    - [Field mapping](#field-mapping)
    - [Account Reference](#account-reference)
  - [Remarks](#remarks)
    - [Concurrent actions to 1](#concurrent-actions-to-1)
    - [`PUT` method for all update actions](#put-method-for-all-update-actions)
    - [Full update within the _update_ lifecycle action](#full-update-within-the-update-lifecycle-action)
    - [Archiving an Ysis-account](#archiving-an-ysis-account)
    - [Conditional event for notification when discipline changes](#conditional-event-for-notification-when-discipline-changes)
    - [Fields "Beroep" and "Opmerking" are cleared](#fields-beroep-and-opmerking-are-cleared)
    - [End date must be cleared](#end-date-must-be-cleared)
    - [Username must be unique in Ysis](#username-must-be-unique-in-ysis)
    - [If the emailaddress is changed, a notification is send to the end user](#if-the-emailaddress-is-changed-a-notification-is-send-to-the-end-user)
  - [Development resources](#development-resources)
    - [API endpoints](#api-endpoints)
    - [API documentation](#api-documentation)
  - [Getting help](#getting-help)
  - [HelloID Docs](#helloid-docs)

## Introduction

The HelloID-Conn-Prov-Target-Ysis is a target connector that creates and updates user accounts, modules and roles within Ysis. Ysis provides a set of SCIM based APIs that allow you to programmatically interact with its data.

The API has a limitation requiring the complete account object to be sent when updating an account. For further details, refer to the Ysis SCIM documentation: [Ysis SCIM Documentation](https://apihelp.gerimedica.nl/category/scim/).

> [!IMPORTANT]
> Changing the discipline of an existing account is not supported. If a discipline change is attempted during the update life-cycle, a conditional event is triggered, sending an email notification to the Ysis administrator.
> - In Ysis each account is assigned a discipline that serves as the account type.
> - If a user requires a different or additional discipline, a new account must be created with the desired discipline. This process involves manual actions by the Ysis administrator.

## Supported features

The following features are available:

| Feature                               | Supported | Notes                                       |
| ------------------------------------- | --------- | ------------------------------------------- |
| Account Lifecycle                     | ✅         | Create, Update, Enable, Disable, Delete     |
| Permissions                           | ✅         | Retrieve, Grant, Revoke - Modules and Roles |
| Resources                             | ❌         | -                                           |
| Entitlement Import: Accounts          | ✅         | -                                           |
| Entitlement Import: Permissions       | ✅         | -                                           |
| Governance Reconciliation Resolutions | ✅ ⚠️       | Discipline changes trigger notification     |

## Getting started

### HelloID Icon URL

The URL of the icon used for the HelloID Provisioning target system:

```
https://raw.githubusercontent.com/Tools4everBV/HelloID-Conn-Prov-Target-Ysis/refs/heads/main/Logo.png
```

### Requirements

- A server with a local agent is required
- The outgoing IP address of the HelloID agent server must be whitelisted by GeriMedica
- A mapping between function and discipline is created
- The end date for active accounts should be cleared (see [End date must be cleared](#end-date-must-be-cleared))

> [!TIP]
> You can validate the outgoing IP address on the HelloID agent server with the following PowerShell script:
> ```powershell
> $ip = Invoke-RestMethod -uri "https://ipinfo.io/json" -method get
> Write-Information -Verbose "$($ip.ip)"
> ```

### Connection settings

The following settings are required to connect to the API.

| Setting                | Description                                                                               |
| ---------------------- | ----------------------------------------------------------------------------------------- |
| ClientID               | The ClientId to connect to the Ysis API                                                   |
| ClientSecret           | The ClientSecret to connect to the Ysis API                                               |
| BaseUrl                | The URL to the Ysis environment. Example: https://company.acceptatie2.ysis.nl             |
| AuthUrl                | The authentication URL to the Ysis environment. Example: https://auth.acceptatie1.ysis.nl |
| MappingFile            | The mapping between function and discipline                                               |
| UpdateUsernameOnDelete | Update username to the YsisIntials when archiving Ysis account                            |

### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within Ysis to a person in HelloID. Correlation within Ysis is only possible on the attribute 'employeeNumber'.

| Setting                   | Value            |
| ------------------------- | ---------------- |
| Enable correlation        | `True`           |
| Person correlation field  | `ExternalId`     |
| Account correlation field | `EmployeeNumber` |

> [!TIP]
> The employee number must be correctly registered for users in Ysis for correlation to work.
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

### Field mapping

The field mapping can be imported by using the [fieldMapping.json](./fieldMapping.json) file.

### Account Reference

The account reference is populated with the `id` property from Ysis.

## Remarks

### Concurrent actions to 1

Set the number of concurrent actions to 1. Otherwise, the modules and roles permission operations of one run will interfere with that of another run.

### `PUT` method for all update actions

All update actions use an `HTTP.PUT` method. This means that the full account object will be sent to Ysis. For both the _enable_ and _disable_ lifecycle actions, we first retrieve the account, update the `active` property accordingly and send back the full object.

### Full update within the _update_ lifecycle action

The _update_ lifecycle action now supports a full account update. Albeit, the update itself is a `PUT`. This means that the __full__ object will be updated within Ysis. Since the update process is also supported from the _create_ lifecycle action, this might have unexpected implications.

Some values may not be available in HelloID because they are not available in the HR system. If these values are added manually in Ysis you need to make sure HelloID sends back the current value in the update.ps1 script. Example:

```powershell
#if not mapped use current value:
if (-not [bool]($account.PSobject.Properties.name -match "agbCode")) {
    $ysisaccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.agbCode = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.agbCode
}

#if not mapped use current value:
if (-not [bool]($account.PSobject.Properties.name -match "bigNumber")) {
    $ysisaccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.bigNumber = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.bigNumber
}
```

### Archiving an Ysis-account

HelloID can archive a Ysis account, but can't dearchive an Ysis account. HelloID will update the Ysis username to the YsisIntials if `updateUsernameOnDelete` is `enabled` to make sure a new account can be created. If updating the username is not used, this can result in messages regarding existing usernames. The archived account then needs to be dearchived manually or corrected by setting a dummy username.

### Conditional event for notification when discipline changes

A conditional event needs to be set up based on changes of the discipline. On this event a notification can be configured to send an e-mail to the Ysis-administrator.

> [!TIP]
> How to configure:
> 1. Make sure `Discipline` is added in the field mapping.
> 2. Go to Business Custom events, create a new custom event. Select the Ysis connector, action `Account update` and add a condition with field `Discipline` is updated.
> 3. Go to Notifications Configuration, create a new notification. Select your Ysis custom event. Import the [_conditional-notification.mjml_](./assets/ConditionalNotification.mjml) template.
>
> _For more information custom events, please refer to our [documentation](https://docs.helloid.com/en/provisioning/notifications--provisioning-/custom-notification-events--conditional-notifications-.html) pages_.

### Fields "Beroep" and "Opmerking" are cleared

When updating an account, the fields "Beroep" and "Opmerking" cannot be set and are instead cleared in Ysis. We have opened a support ticket with Ysis and will provide updates on this issue as more information becomes available.

### End date must be cleared

Existing end dates must be cleared for [active] accounts. When HelloID manages the person card in Ysis, it is blocked on the contract's end date. The existing end date in Ysis cannot be modified via the Ysis web service. Ysis automatically blocks individuals whose end date has passed in Ysis, even if HelloID has reactivated the person.

### Username must be unique in Ysis

The attribute Username must also be unique in Ysis (active, inactive, and archived)

### If the emailaddress is changed, a notification is send to the end user

If the value in the attribute Email is changed, a notification is send to the end user. This also happens when changing the emailaddress in the test environment.

## Development resources

### API endpoints

The HelloID connector uses the API endpoints listed in the table below.

| Endpoint                 | Method                 | Description                                                                     |
| ------------------------ | ---------------------- | ------------------------------------------------------------------------------- |
| /cas/oauth/token         | POST                   | Generate an authorization token                                                 |
| /gm/api/um/scim/v2/users | GET, POST, PUT, DELETE | Search, create, update an account; assign or remove modules or roles to account |
| /gm/api/um/scim/v2/roles | GET                    | Get role data; default roles and custom roles                                   |

### API documentation

For more information on the Ysis API, please refer to the [Ysis SCIM Documentation](https://apihelp.gerimedica.nl/category/scim/).

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_

## HelloID Docs

The official HelloID documentation can be found at: https://docs.helloid.com/
