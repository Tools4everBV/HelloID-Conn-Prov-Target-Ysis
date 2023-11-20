########################################
# HelloID-Conn-Prov-Target-YsisV2-Create
#
# Version: 1.1.0
########################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Account mapping
$account = [PSCustomObject]@{
    schemas                                                      = @('urn:ietf:params:scim:schemas:core:2.0:User', 'urn:ietf:params:scim:schemas:extension:ysis:2.0:User', 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User')
    userName                                                     = $p.ExternalId
    name                                                         = [PSCustomObject]@{
        givenName  = $p.Name.NickName
        familyName = switch ($p.Name.Convention) {
            'B' { $p.Name.FamilyName }
            'PB' { $p.Name.FamilyNamePartner + ' - ' + $p.Name.FamilyNamePrefix + ' ' + $p.Name.FamilyName }
            'P' { $p.Name.FamilyNamePartner }
            default { $p.Name.FamilyName + ' - ' + $p.Name.FamilyNamePartnerPrefix + ' ' + $p.Name.FamilyNamePartner }
        }
        infix      = switch ($p.Name.Convention) {
            'P' { $p.Name.FamilyNamePartnerPrefix }
            'PB' { $p.Name.FamilyNamePartnerPrefix }
            default { $p.Name.FamilyNamePrefix }
        }
    }
    gender                                                       = switch ($p.Details.Gender) {
        "V" { "FEMALE" }
        "M" { "MALE" }
        default { "UNKNOWN" }
    }
    emails                                                       = @(
        [PSCustomObject]@{
            value   = $p.accounts.MicrosoftActiveDirectory.mail
            type    = 'work'
            primary = $true
        }
    )
    roles                                                        = @(
        [PSCustomObject]@{
            value       = ''
            displayName = ''
        }
    )
    entitlements                                                 = @()
    phoneNumbers                                                 = @(
        [PSCustomObject]@{
            value = $p.Contact.Business.Phone.Fixed
            type  = 'work'
        },
        [PSCustomObject]@{
            value = $p.Contact.Business.Phone.Mobile
            type  = 'mobile'
        }
    )
    'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'       = [PSCustomObject]@{
        ysisInitials = ''
        discipline   = ''
        agbCode      = $null
        initials     = $p.Name.Initials
        bigNumber    = $null
        position     = $p.PrimaryContract.Title.Name
        modules      = @('YSIS_CORE') 
    }
    "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" = [PSCustomObject]@{
        employeeNumber = $p.ExternalId
    }
    userType                                                     = ''
    password                                                     = ''
}

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
function Set-YsisV2Password {
    param (
        [int]
        $Length,

        [string]
        $Characters
    )

    $random = 1..$Length | ForEach-Object { Get-Random -Maximum $Characters.Length }
    Write-Output ($Characters[$random] -join '')
}

function Set-YsisV2Initials {
    param (
        [object]
        $PersonObject
    )

    $initials = $PersonObject.ExternalId + '-' + ($PersonObject.Name.Initials -replace '\.')
    if ($initials.Length -gt 10) {
        $initials = $initials.Substring(0, 10)
    }

    Write-Output $initials
}

function Resolve-YsisV2Error {
    param (
        [object]
        $ErrorObject
    )
    $httpErrorObj = [PSCustomObject]@{
        ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
        Line             = $ErrorObject.InvocationInfo.Line
        ErrorDetails     = $ErrorObject.Exception.Message
        FriendlyMessage  = $ErrorObject.Exception.Message
    }

    try {
        if ($null -eq $ErrorObject.ErrorDetails) {
            $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
            if ($null -ne $streamReaderResponse) {
                $convertedError = $streamReaderResponse | ConvertFrom-Json
                $httpErrorObj.ErrorDetails = "Message: $($convertedError.error), description: $($convertedError.error_description)"
                $httpErrorObj.FriendlyMessage = "Message: $($convertedError.error), description: $($convertedError.error_description)"
            }
        }
        else {
            $errorResponse = $ErrorObject.ErrorDetails | ConvertFrom-Json
            $httpErrorObj.ErrorDetails = "Message: $($errorResponse.detail), type: $($errorResponse.scimType)"
            $httpErrorObj.FriendlyMessage = "$($errorResponse.detail), type: $($errorResponse.scimType)"
        }
    }
    catch {
        $httpErrorObj.FriendlyMessage = "Received an unexpected response. The JSON could not be converted, error: [$($_.Exception.Message)]. Original error from web service: [$($ErrorObject.Exception.Message)]"
    }
    Write-Output $httpErrorObj
}

function Set-YsisRole {
    param (
        [string]
        $RoleDescription
    )

    #Retrieve Roles from YSIS
    $splatRoleParams = @{
        Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/roles"
        Method      = 'GET'
        Headers     = $headers
        ContentType = 'application/json'
    }
    $ysisroles = Invoke-RestMethod @splatRoleParams -Verbose:$false
    $ysisrole = $ysisroles | Where-Object displayName -eq $RoleDescription

    Write-Output $ysisrole.value
}
#endregion

# Begin
try {
    # Verify if [account.ExternalId] has a value
    if ([string]::IsNullOrEmpty($($account.'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User'.employeeNumber))) {
        throw 'Mandatory attribute [account.ExternalId] is empty. Please make sure it is correctly mapped'
    }

    # Import mapping
    $mapping = Import-Csv $config.MappingFile -Delimiter ";"
    $mappedObject = $mapping | Where-Object { $_.Id -eq $p.PrimaryContract.Title.ExternalId }
    $account.userType = $mappedObject.Discipline
    $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline = $mappedObject.Discipline

    # Add account password and initials to the account object.
    $account.password = (Set-YsisV2Password -Length 12 -Characters 'ABCDEFGHKLMNOPRSTUVWXYZ1234567890!@#&')
    $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials = Set-YsisV2Initials -Person $p

    # Requesting authorization token
    $splatRequestToken = @{
        Uri    = "$($config.BaseUrl)/cas/oauth/token"
        Method = 'POST'
        Body   = @{
            client_id     = $($config.ClientID)
            client_secret = $($config.ClientSecret)
            scope         = 'scim'
            grant_type    = 'client_credentials'
        }
    }
    $responseAccessToken = Invoke-RestMethod @splatRequestToken -Verbose:$false

    Write-Verbose 'Adding Authorization headers'
    $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
    $headers.Add('Authorization', "Bearer $($responseAccessToken.access_token)")
    $headers.Add('Accept', 'application/json')
    $headers.Add('Content-Type', 'application/json')

    # Verify if a user must be either [created and correlated], [updated and correlated] or just [correlated]
    Write-Verbose "Verifying if YsisV2 account for [$($p.DisplayName)] exists"
    $encodedString = [System.Uri]::EscapeDataString($($account.'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User'.employeeNumber))
    $splatParams = @{
        Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users?filter=urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:employeeNumber%20eq%20%22$encodedString%22"
        Method      = 'GET'
        Headers     = $headers
        ContentType = 'application/json'
    }
    $response = Invoke-RestMethod @splatParams -Verbose:$false
    $responseUser = $response | Select-Object -First 1

    # If the discipline on the account in Ysis matches with the discipline on the account object, the account can be either updated or correlated.
    # If the discipline does not match, a new account will be created.
    if ($responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline -ne $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline -or $null -eq $responseUser) {
        $action = 'Create-Correlate'
    }
    elseif ($config.UpdatePersonOnCorrelate -eq $true -and $responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline -eq $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline) {
        $action = 'Update-Correlate'
    }
    else {
        $action = 'Correlate'
    }

    

    #Set role in account
    $account.roles[0].displayName = $mappedObject.Description   
    $account.roles[0].value = Set-YsisRole -RoleDescription $mappedObject.Description

    # Add a warning message showing what will happen during enforcement
    if ($dryRun -eq $true) {
        Write-Warning "[DryRun] $action YsisV2 account of type: [$($account.userType)] and discipline: [$($account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline)] for: [$($p.DisplayName)], will be executed during enforcement"
        switch ($action) {
            'Create-Correlate' {
                $reference = @{
                    Id           = $null
                    UserName     = $account.userName
                    YsisInitials = $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials
                    Discipline   = $account.discipline
                }
                break
            }
            default {
                $reference = @{
                    Id           = $responseUser.id
                    UserName     = $responseUser.userName
                    YsisInitials = $responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials
                    Discipline   = $responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline
                }
                break
            } 
        }  
    }

    # Process
    if (-not($dryRun -eq $true)) {
        switch ($action) {
            'Create-Correlate' {
                Write-Verbose 'Creating and correlating YsisV2 account'                
                $splatCreateUserParams = @{
                    Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users"
                    Headers     = $headers
                    Method      = 'POST'
                    Body        = $account | ConvertTo-Json
                    ContentType = 'application/scim+json'
                }
                $responseCreateUser = Invoke-RestMethod @splatCreateUserParams -Verbose:$false
                $reference = @{
                    Id           = $responseCreateUser.id
                    UserName     = $responseCreateUser.userName
                    YsisInitials = $responseCreateUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials
                    Discipline   = $responseCreateUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline
                }
                break
            }

            'Update-Correlate' {
                Write-Verbose 'Updating and correlating YsisV2 account'
                # The password is immutable and therefore, cannot be updated
                $account.PSObject.Properties.Remove('password')
                # Set Ysis-Initials to existing
                $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials = $responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials
                
                # Set Gender to existing if unknown in person
                if ([String]::IsNullOrEmpty($p.Details.Gender)) {
                    $account.Gender = $responseUser.Gender
                }

                # Set Phonenumbers to existing
                $account.phoneNumbers[0].value = ($responseUser.phoneNumbers | Where-Object type -eq 'work').value
                $account.phoneNumbers[1].value = ($responseUser.phoneNumbers | Where-Object type -eq 'mobile').value

                # Set Roles to existing
                if (!([string]::IsNullOrEmpty($responseUser.roles))) {
                    $account.roles = $responseUser.roles
                }
                
                # Set Modules to existing
                if ($responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules.count -gt 0) {
                    $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules = $responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules
                }
                
                $splatUpdateUserParams = @{
                    Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($responseUser.id)"
                    Headers     = $headers
                    Method      = 'PUT'
                    Body        = $account | ConvertTo-Json
                    ContentType = 'application/scim+json'
                }
                $responseUpdateUser = Invoke-RestMethod @splatUpdateUserParams -Verbose:$false
                $reference = @{
                    Id           = $responseUpdateUser.id
                    UserName     = $responseUpdateUser.userName
                    YsisInitials = $responseUpdateUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials
                    Discipline   = $responseUpdateUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline
                }
                break
            }

            'Correlate' {
                Write-Verbose 'Correlating YsisV2 account'
                $reference = @{
                    Id           = $responseUser.id
                    UserName     = $responseUser.userName
                    YsisInitials = $responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials
                    Discipline   = $responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline
                }
                $accountReference = $reference
                break
            }
        }

        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Message = "$action account was successful. AccountReference is: [$accountReference]"
                IsError = $false
            })
    }
}
catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-YsisV2Error -ErrorObject $ex
        $auditMessage = "Could not $action YsisV2 account. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Could not $action YsisV2 account. Error: $($ex.Exception.Message)"
        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $auditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
    # End
}
finally {
    $result = [PSCustomObject]@{
        Success          = $success
        AccountReference = $reference
        Auditlogs        = $auditLogs
        Account          = $account

        # Optionally return data for use in other systems
        ExportData       = [PSCustomObject]@{
            ysisInitials = $reference.ysisInitials
            Discipline   = $reference.Discipline
        }
    }

    Write-Output $result | ConvertTo-Json -Depth 10
}