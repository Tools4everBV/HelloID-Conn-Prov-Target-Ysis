# HelloID-Conn-Prov-Target-YsisV2
| :warning: Warning |
|:---------------------------|
| This script is for the new powershell connector. Make sure to use the mapping and correlation keys like mentionded in this readme. For more information, please read our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html). Note that this connector is not yet implemented. Contact our support for further assistance.       |

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |


<p align="center">
  <img src="https://www.tools4ever.nl/connector-logos/ysis-logo.png" width="500">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-YsisV2](#helloid-conn-prov-target-ysisv2)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Connection settings](#connection-settings)
    - [Remarks](#remarks)
      - [`PUT` method for all update actions](#put-method-for-all-update-actions)
      - [Full update within the _update_ lifecycle action](#full-update-within-the-update-lifecycle-action)
      - [Discipline and the Ysis-initals are stored in `$aRef`](#discipline-and-the-ysis-initals-are-stored-in-aref)
      - [Archiving an Ysis account](#archiving-an-ysis-account)
  - [Mapping](#mapping)
  - [Correlation](#correlation)
  - [Conditional Event](#conditional-event)
  - [Getting help](#getting-help)
  - [HelloID Docs](#helloid-docs)

## Introduction

The HelloID-Conn-Prov-Target-YsisV2 connector creates and updates user accounts within Ysis. The Ysis API is a SCIM based (http://www.simplecloud.info) API and has some limitations for our provisioning process. For more information you can check the Ysis SCIM documentation (https://apihelp.gerimedica.nl/category/scim/).

>:exclamation:It is not possible to change the discipline of an existing account. Therefore, during the `update` life-cycle a change in discipline will launch a conditional event which sends an email to the Ysis administrator.

- In Ysis each account has a discipline that acts as the account type.
- When a person requires a different (or an extra discipline), a new user account must be created with the new discipline. Manual actions by the Ysis administrator are needed.

## Introduction
The interface to communicate with Profit is through a set of GetConnectors, which is component that allows the creation of custom views on the Profit data. GetConnectors are based on a pre-defined 'data collection', which is an existing view based on the data inside the Profit database. 

For this connector we have created a default set, which can be imported directly into the AFAS Profit environment.
The HelloID connector consists of the template scripts shown in the following table.

| Action                          | Action(s) Performed   | Comment   | 
| ------------------------------- | --------------------- | --------- |
| create.ps1                      | Create or correlate Ysis account  | Create or correlates an Ysis account. If correlated and UpdateOnCorrelate is configured, the update will be processed |
| enable.ps1                      | Activate Ysis account  | Activates Ysis account |
| update.ps1                      | Update Ysis account  | Update on Ysis account. Conditional event on discipline change. |
| disable.ps1                     | Deactivate Ysis account  | Deactivates Ysis account |
| delete.ps1                      | Archive Ysis account  | Archives the Ysis account |

<!-- GETTING STARTED -->
## Getting Started

### Prerequisites

- [ ] The outgoing IP address of the HelloID agentserver must be whitelisted by GeriMedica.
- [ ] Mapping between function and discipline.

### Connection settings

The following settings are required to connect to the API.

| Setting     | Description |
| ------------ | ----------- |
| ClientID     | The ClientId to connect to the Ysis API   |
| ClientSecret | The ClientSecret to connect to the Ysis API  |
| BaseUrl      | The URL to the Ysis environment. Example: https://company.acceptatie2.ysis.nl

### Remarks

#### `PUT` method for all update actions

All update actions use an `HTTP.PUT` method. This means that the full account object will be send to Ysis. For both the _enable_ and _disable_ lifecycle actions, we first retrieve the account, update the `active` property accordingly and send back the full object.

#### Full update within the _update_ lifecycle action

The _update_ lifecycle action now supports a full account update. Albeit, the update itself is a `PUT`. This means that the __full__ object will be updated within Ysis. Since the update process is also supported from the _create_ lifecycle action, this might have unexpected implications.

#### Discipline and the Ysis-initals are stored in `$aRef`

When HelloID has created the Ysis account, the _discipline_ will be stored in the account reference. That makes it possible to, within the update lifecycle action, verify if the _discipline_ has changed. Whenever a change has been detected, an email will be send indicating that that a new account must be created or the existing one must be updated. The _discipline_ will also be included in this email.

#### Archiving an Ysis-account

HelloID can archive an Ysis account, but can't dearchive an Ysis account. This can result in messages regarding existing usernames. The archived account than needs to be dearchived manually or corrected by setting a dummy username.

### Mapping
The mandatory and recommended field mapping is listed below. Some fields are required by Ysis and are set on creating an account. When an update is triggered, the required/immutable fields are set to the existing values from the existing user.

| Name           | Create | Enable | Update | Disable | Delete | Store in account data | Default mapping                            | Mandatory | Comment                                        |
| -------------- | ------ | ------ | ------ | ------- | ------ | --------------------- | ------------------------------------------ | --------- | ---------------------------------------------- |
| AgbCode     | X      |        | X      |         |        | No            |  None       |        |  |
| BigNumber | X      |        | X      |         |        | No  | None  |        | |
| Discipline           | X       |        | X      |         |        | Yes                   | Calculated by create and update | Yes          | Calculated in script to trigger a conditional event  |
| Email           | X       |        | X      |         |        | No                   | Mailaddress from dependent system |           | E-Mail work; Ysis accepts only one mailaddress                                  |
| EmployeeNumber           | X       |        | X      |         |        | No                   | ExternalId | Yes          | Employeenumber                                    |
| FamilyName           | X       |        | X      |         |        | No                   | LastName |  Yes         | Lastname based on naming convention                                    |
| Gender           | X       |        | X      |         |        | No                   | Gender |           | Gender                                    |
| GivenName           | X       |        | X      |         |        | No                   | NickName | Yes          | Nickname                                    |
| Infix           | X       |        | X      |         |        | No                   |LastName prefix |           | Prefix based on naming convention|
| Initials           | X       |        | X      |         |        | No                   | Initials | Yes          | Initials; required but immutable                                    |
| MobilePhone           | X       |        | X      |         |        | No                   | Work mobile |           | Mobile phonenumber                                    |
| Password           | X      |        |        |         |        | No                   | Generated | Yes (on creation)           | Initial password on creation                                   |
| Position           | X       |        | X      |         |        | No                   | Title |           | Jobtitle                                    |
| UserName           | X       |        | X      |         | X      | No                   | Username from dependent system | Yes          | Unique username in Ysis, also used for SSO                   |
| WorkPhone           | X       |        | X      |         |        | No                   | Work phone |           | Fixed phonenumber                                    |
| YsisInitials           | X       |        | X      |         | X      | Yes                   | Generated | Yes          | Required immutable unique combination                                    |

### Correlation
It is mandatory to enable the correlation in the correlation tab. The default value for "person correlation field" is " ExternalId". The default value for "Account Correlation field" is "EmployeeNumber".

### Conditional Event
A conditional event needs to be set up based on changes of the discipline. On this event a notification can be configured to send an e-mail to the Ysis-administrator.

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID Docs

The official HelloID documentation can be found at: https://docs.helloid.com/
