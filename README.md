# HelloID-Conn-Prov-Target-Ysis

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-YsisV2/blob/main/Logo.png?raw=true">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-Ysis](#helloid-conn-prov-target-Ysis)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Connection settings](#connection-settings)
    - [Correlation configuration](#correlation-configuration)
    - [Field mapping](#field-mapping)  
    - [Remarks](#remarks)
      - [Concurrent actions to 1](#Concurrent-actions-to-1)
      - [`PUT` method for all update actions](#put-method-for-all-update-actions)
      - [Full update within the _update_ lifecycle action](#full-update-within-the-update-lifecycle-action)
      - [Archiving an Ysis-account](#archiving-an-ysis-account)
      - [Conditional event for notification when discipline changes](#conditional-event)
      - [Fields "Beroep" and "Opmerking" are cleared](#fields-beroep-and-opmerking-are-cleared)
      - [End date must be cleared](#end-date-must-be-cleared)
      - [Username must be unique in Ysis](#username-must-be-unique-in-ysis)
  - [Getting help](#getting-help)
  - [HelloID Docs](#helloid-docs)

## Introduction

The HelloID-Conn-Prov-Target-Ysis is a _target_ connector that creates and updates user accounts, modules and roles within Ysis.

Ysis provides a set of SCIM (http://www.simplecloud.info) based API's. The HelloID connector uses the API endpoints listed in the table below.

| Endpoint | Description |
| -------- | ----------- |
| /cas/oauth/token | Generate an authorization token 
| /gm/api/um/scim/v2/users | Search, create or update an account; assign or remove modules or roles to account |
| /gm/api/um/scim/v2/roles | Get role data; default roles and custom roles |
 
The API has a limitation requiring the complete account object to be sent when updating an account. For further details, refer to the Ysis SCIM documentation: Ysis SCIM Documentation. (https://apihelp.gerimedica.nl/category/scim/

> [!IMPORTANT] Changing the discipline of an existing account is not supported. If a discipline change is attempted during the update life-cycle, a conditional event is triggered, sending an email notification to the Ysis administrator.
- In Ysis each account is assigned a discipline that serves as the account type.
- If a user requires a different or additional discipline, a new account must be created with the desired discipline. This process involves manual actions by the Ysis administrator.

The following lifecycle action scripts and supporting files are available:
| Action                                   | Description                                      |
| -----------------------------------------| ------------------------------------------------ |
| create.ps1                               | PowerShell _create_ or _correlate_ lifecycle action. If correlated and UpdateOnCorrelate is configured, the update script will be processed |
| delete.ps1                               | PowerShell _delete_ lifecycle action. Archives the Ysis account, optionally update Username to YsisInitials |
| disable.ps1                              | PowerShell _disable_ lifecycle action |
| enable.ps1                               | PowerShell _enable_ lifecycle action |
| update.ps1                               | PowerShell _update_ lifecycle action. Conditional event on discipline change |
| permissions/modules/grantPermission.ps1  | PowerShell _grant_ module lifecycle action |
| permissions/modules/revokePermission.ps1 | PowerShell _revoke_ module lifecycle action |
| permissions/modules/permissions.ps1      | PowerShell _permissions_ modules lifecycle action |
| permissions/roles/grantPermission.ps1    | PowerShell _grant_ role lifecycle action |
| permissions/roles/revokePermission.ps1   | PowerShell _revoke_ role lifecycle action |
| permissions/roles/permissions.ps1        | PowerShell _permissions_ roles lifecycle action |
| configuration.json                       | Default _configuration.json_ |
| fieldMapping.json                        | Default _fieldMapping.json_ |
| assets/YsisMapping.csv                   | Example Ysis discipline _mapping csv_ |
| assets/ConditionalNotification.mjml      | Example Discipline has changed _notification_ |

## Getting Started

### Prerequisites

- A server with a local agent is required.
- The outgoing IP address of the HelloID agent server must be whitelisted by GeriMedica.
- A mapping between function and discipline is created.
- The end date for active accounts should be cleared (see [End date must be cleared](#end-date-must-be-cleared)

> [!TIP]
> You can validate the outgoing IP address on the HelloID agent server with the following PowerShell script:
> ```powershell
> $ip = Invoke-RestMethod -uri "https://ipinfo.io/json" -method get
> Write-Verbose -Verbose "$($ip.ip)"
> ```

### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _HelloID-Conn-Prov-Target-Ysis to a person in _HelloID_.

    | Setting                   | Value            |
    | ------------------------- | ---------------- |
    | Enable correlation        | `True`           |
    | Person correlation field  | `ExternalId`     |
    | Account correlation field | `EmployeeNumber` |

> [!TIP]
> The employee number must be correctly registered for users in Ysis for correlation to work.
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

### Field mapping

The field mapping can be imported by using the [_fieldMapping.json_](./fieldMapping.json) file.

### Connection settings

The following settings are required to connect to the API.

| Setting                 | Description                                                                   |
| ----------------------- | ----------------------------------------------------------------------------- |
| ClientID                | The ClientId to connect to the Ysis API                                       |
| ClientSecret            | The ClientSecret to connect to the Ysis API                                   |
| BaseUrl                 | The URL to the Ysis environment. Example: https://company.acceptatie2.ysis.nl |
| DefaultModule           | The default module code. Default value: `YSIS_CORE`                           |
| MappingFile             | The mapping between function and discipline                                   |
| UpdatePersonOnCorrelate | This will update the account in the target application during correlation     |
| UpdateUsernameOnDelete  | Update username to the YsisIntials when archiving Ysis account                |
| IsDebug                 | When toggled, debug logging will be displayed                                 |


### Remarks

#### Concurrent actions to 1
Set the number of concurrent actions to 1. Otherwise, the modules and roles permission operations of one run will interfere with that of another run.

#### `PUT` method for all update actions

All update actions use an `HTTP.PUT` method. This means that the full account object will be send to Ysis. For both the _enable_ and _disable_ lifecycle actions, we first retrieve the account, update the `active` property accordingly and send back the full object.

#### Full update within the _update_ lifecycle action

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

#### Archiving an Ysis-account

HelloID can archive a Ysis account, but can't dearchive an Ysis account.  HelloID will update the Ysis username to the YsisIntials if `updateUsernameOnDelete` is `enabled` i to make sure a new account can be created. If updating the username is not used. Then this can result in messages regarding existing usernames. The archived account then needs to be dearchived manually or corrected by setting a dummy username.

#### Conditional event for notification when discipline changes
A conditional event needs to be set up based on changes of the discipline. On this event a notification can be configured to send an e-mail to the Ysis-administrator.

> [!TIP]
> How to configure:
> 1. Make sure `Discipline` is added in the field mapping and the option `Use in notifications` is on.
> 2. Go to Business Custom events, create a new custom event. Select the Ysis connector, action `Account update` and add a condition with field `Discipline` is updated.
> 3. Go to Notifications Configuration, create a new notification. Select your Ysis custom event. Import the [_conditional-notification.mjml_](./conditional-notification.mjml) template.
>
> _For more information custom events, please refer to our [documentation](https://docs.helloid.com/en/provisioning/notifications--provisioning-/custom-notification-events--conditional-notifications-.html) pages_.

#### Fields "Beroep" and "Opmerking" are cleared
When updating an account, the fields "Beroep" and "Opmerking" cannot be set and are instead cleared in Ysis. We have opened a support ticket with Ysis and will provide updates on this issue as more information becomes available.

#### End date must be cleared
Existing end dates must be cleared for [active] accounts. When HelloID manages the person card in Ysis, it is blocked on the contract's end date. The existing end date in Ysis cannot be modified via the Ysis web service. Ysis automatically blocks individuals whose end date has passed in Ysis, even if HelloID has reactivated the person.

### Username must be unique in Ysis
The attribute Username must also be unique in Ysis (active, inactive, and archived)

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID Docs

The official HelloID documentation can be found at: https://docs.helloid.com/