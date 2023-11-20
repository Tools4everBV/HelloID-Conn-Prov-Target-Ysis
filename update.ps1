########################################
# HelloID-Conn-Prov-Target-YsisV2-Update
#
# Version: 1.1.0
########################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Smtp configuration
$smtpServerAddress = '127.0.01'
$to = 'JohnDoe@enyoi.local'

# Account mapping
$account = [PSCustomObject]@{
    id                                                           = $($aRef.Id)
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
    active                                                       = $true
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
    roles                                                        = @()
    entitlements                                                 = @()
    phoneNumbers                                                 = @(
        [PSCustomObject]@{
            value = $p.Contact.Business.Phone.Fixed
            type  = 'work'
        }
    )
    'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'       = [PSCustomObject][ordered]@{
        # Initials must be unique within Ysis
        ysisInitials = ''
        discipline   = ''
        agbCode      = $null
        initials     = $p.Name.Initials ##immutable
        bigNumber    = $null
        position     = $p.PrimaryContract.Title.Name
        modules      = @()
    }
    "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" = [PSCustomObject]@{
        employeeNumber = $p.ExternalId
    }
}

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
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
#endregion

# Begin
try {
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($aRef))) {
        throw 'The account reference could not be found'
    }

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

    Write-Verbose "Verifying if YsisV2 account for [$($p.DisplayName)] exists"
    try {
        $splatParams = @{
            Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($aRef.Id)"
            Headers     = $headers
            ContentType = 'application/json'
        }
        $currentAccount = Invoke-RestMethod @splatParams -Verbose:$false
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            $auditLogs.Add([PSCustomObject]@{
                    Message = "YsisV2 account for: [$($p.DisplayName)] not found. Possibly deleted"
                    IsError = $false
                })
        }
        throw
    }

    # Set Ysis-Initials & Initials to existing
    # Both are mandatory but immutable
    $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials
    $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.initials = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.initials

    # Set Gender to existing if unknown in person
    if ([String]::IsNullOrEmpty($p.Details.Gender)) {
        $account.Gender = $currentAccount.Gender
    }

    # Set Phonenumbers to existing
    $account.phoneNumbers[0].value = ($currentAccount.phoneNumbers | Where-Object type -eq 'work').value
    $account.phoneNumbers[1].value = ($currentAccount.phoneNumbers | Where-Object type -eq 'mobile').value

    # Set Roles to existing
    $account.roles = $currentAccount.roles
    
    # Set Modules to existing
    $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules
    
    # Import mapping
    $mapping = Import-Csv $config.MappingFile -Delimiter ";"
    $mappedObject = $mapping | Where-Object { $_.Id -eq $p.PrimaryContract.Title.ExternalId }
    $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline = $mappedObject.Discipline

    # Verify if discipline needs an update
    if ($aRef.Discipline -ne $($account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline)) {
        $action = 'Update-Discipline'
        $dryRunMessage = "The account discipline has changed from: [$($currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline)] to: [$($account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline)]."
    }
    else {
        # Compare objects
        $splatCompareProperties = @{
            ReferenceObject  = @($currentAccount.PSObject.Properties)
            DifferenceObject = @($account.PSObject.Properties)
        }
        $propertiesChanged = (Compare-Object @splatCompareProperties -PassThru).Where({ $_.SideIndicator -eq '=>' })
        if ($propertiesChanged) {
            $action = 'Update'
            $dryRunMessage = "Account property(s) required to update: [$($propertiesChanged.name -join ",")]"
        }
        elseif (-not $propertiesChanged) {
            $action = 'NoChanges'
            $dryRunMessage = 'No changes will be made to the account during enforcement'
        }
        elseif ($null -eq $currentAccount) {
            $action = 'NotFound'
            $dryRunMessage = "YsisV2 account for: [$($p.DisplayName)] not found. Possibly deleted"
        }
    }

    Write-Verbose $dryRunMessage

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        Write-Warning "[DryRun] $dryRunMessage"
    }

    # Process
    if (-not($dryRun -eq $true)) {
        switch ($action) {
            'Update' {
                Write-Verbose "Updating YsisV2 account with accountReference: [$($aRef.Id)]"
                $splatUpdateUserParams = @{
                    Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($aRef.Id)"
                    Headers     = $headers
                    Method      = 'PUT'
                    Body        = $account | ConvertTo-Json
                    ContentType = 'application/scim+json'
                }
                $null = Invoke-RestMethod @splatUpdateUserParams -Verbose:$false
                $success = $true
                $auditLogs.Add([PSCustomObject]@{
                        Message = 'Update account was successful'
                        IsError = $false
                    })
                break
            }

            'Update-Discipline' {
                Write-Verbose "The discipline for account with accountReference: [$($aRef.Id)] has changed to: [$($account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline)]"
                $mailBody = "
                <p>Dear [Recipient],
                </p>
                <p>The discipline of person [$($p.DisplayName)] has been updated from: [$($aRef.Discipline)] to: [$($account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline)]. However, we would like to bring to your attention that HelloId will <b>not</b> automatically update the account.<Br>
                </p>
                <p>Kindly take action and manually update the account for: [$($p.DisplayName)] with the new discipline.</p>
                <p>Kind regards,<br>
                </p>
                <p>HelloID<br>
                </p>
                "
                $Subject = "Ysis: The discipline for user: [$($aRef.Id)] will need to be updated to [$($account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline)]"

                $splatMailParams = @{
                    From       = 'noreply@HelloID.com'
                    To         = $to
                    Subject    = $Subject
                    SmtpServer = $smtpServerAddress
                    UseSsl     = $false
                    BodyAsHtml = $true
                    Body       = $mailBody
                }
                Send-MailMessage @splatMailParams -ErrorAction Stop
                $success = $true
                $auditLogs.Add([PSCustomObject]@{
                        Message = "The discipline for person: [$($p.DisplayName)] needs to be updated to: [$discipline]. An email is sent to: [$($splatMailParams.To)]"
                        IsError = $false
                    })
            }

            'NoChanges' {
                Write-Verbose "No changes to YsisV2 account with accountReference: [$aRef]"
                $success = $true
                $auditLogs.Add([PSCustomObject]@{
                        Message = 'No changes will be made to the account during enforcement'
                        IsError = $false
                    })
                break
            }

            'NotFound' {
                $success = $false
                $auditLogs.Add([PSCustomObject]@{
                        Message = "YsisV2 account for: [$($p.DisplayName)] not found. Possibly deleted"
                        IsError = $true
                    })
                break
            }
        }
    }
}
catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-YsisV2Error -ErrorObject $ex
        $auditMessage = "Could not update YsisV2 account. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Could not update YsisV2 account. Error: $($ex.Exception.Message)"
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
        Success   = $success
        Account   = $account
        Auditlogs = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}
