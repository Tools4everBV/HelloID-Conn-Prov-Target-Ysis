# HelloID-Conn-Prov-Target-YsisV2

| :Information: Warning |
|:---------------------------|
| This connector replaces the current [Ysis connector](https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Ysis).  |


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
      - [Discipline is stored in `$aRef`](#discipline-is-stored-in-aref)
  - [Getting help](#getting-help)
  - [HelloID Docs](#helloid-docs)

## Introduction

The HelloID-Conn-Prov-Target-Ysis connector creates and updates user accounts within Ysis. The Ysis API is a SCIM based (http://www.simplecloud.info) API and has some limitations for our provisioning process.

>:exclamation:It is not possible to change the discipline of an existing account. Therefore, the `update` lifecycle action sends an email to the Ysis administrator and treats the update action as success when the email is sent.

- In Ysis each account has a discipline that acts as the account type.
- When a person requires a different (or an extra discipline), a new user account must be created with the new discipline.

## Getting started

### Prerequisites

- [ ] The outgoing IP address must be whitelisted by GeriMedica.
- [ ] Mapping between function and discipline.

### Connection settings

The following settings are required to connect to the API.

| Setting     | Description |
| ------------ | ----------- |
| ClientID     | The ClientId to connect to the Ysis API   |
| ClientSecret | The ClientSecret to connect to the Ysis API  |
| BaseUrl      | The URL to the Ysis environment. Example: https://tools4ever.acceptatie1.ysis.nl

### Remarks

#### `PUT` method for all update actions

All update actions use an `HTTP.PUT` method. This means that the full account object will be send to Ysis. For both the _enable_ and _disable_ lifecycle actions, we first retrieve the account, update the `active` property accordingly and send back the full object.

#### Full update within the _update_ lifecycle action

The _update_ lifecycle action now supports a full account update. Albeit, the update itself is a `PUT`. This means that the __full__ object will be updated within Ysis. Since the update process is also supported from the _create_ lifecycle action, this might have unexpected implications.

#### Discipline is stored in `$aRef`

When HelloID has created the Ysis account, the _discipline_ will be stored in the account reference. That makes it possible to, within the update lifecycle action, verify if the _discipline_ has changed. Whenever a change has been detected, an email will be send indicating that that a new account must be created or, the existing one must be updated. The _discipline_ will also be included in this email.

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID Docs

The official HelloID documentation can be found at: https://docs.helloid.com/
