#################################################
# HelloID-Conn-Prov-Target-Ysis-Update
# PowerShell V2
#################################################

# Initialize default values
$config = $actionContext.Configuration
$person = $personContext.Person

$disciplineSearchField = "JobTitleId"

# AccountReference must have a value
$outputContext.AccountReference = $actionContext.References.Account

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($actionContext.Configuration.isDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

function Resolve-YsisError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $convertedError = $streamReaderResponse | ConvertFrom-Json
                    $httpErrorObj.ErrorDetails = "Message: $($convertedError.error), description: $($convertedError.error_description)"
                    $httpErrorObj.FriendlyMessage = "$($convertedError.error), description: $($convertedError.error_description)"
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            if ($errorDetailsObject.PSObject.Properties.Name -contains 'scimType') {
                $httpErrorObj.ErrorDetails = "Message: $($errorDetailsObject.detail), type: $($errorDetailsObject.scimType)"
                $httpErrorObj.FriendlyMessage = "$($errorDetailsObject.detail), type: $($errorDetailsObject.scimType)"
            }
        }
        catch {
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
        }
        Write-Output $httpErrorObj
    }
}

try {
    # Create account object from mapped data and set the correct account reference
    $account = $actionContext.Data

    # Remove ID field because only used for export data
    if ($account.PSObject.Properties.Name -Contains 'id') {
        $account.PSObject.Properties.Remove('id')
    }

    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
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

    $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
    $headers.Add('Authorization', "Bearer $($responseAccessToken.access_token)")
    $headers.Add('Accept', 'application/json; charset=utf-8')
    $headers.Add('Content-Type', 'application/json')

    Write-Verbose "Verifying if Ysis account for [$($person.DisplayName)] exists"
    try {
        $splatParams = @{
            Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($actionContext.References.Account)"
            Headers     = $headers
            ContentType = 'application/scim+json;charset=UTF-8'
        }
        $currentAccount = Invoke-RestMethod @splatParams -Verbose:$false
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Warning "Ysis account for [$($person.DisplayName)] could not be found by accountreference [$($actionContext.References.Account)] and is possibly deleted. To create or correlate a new account, unmanage the account entitlement and rerun an enforcement"
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "UpdateAccount"
                    Message = "Ysis account for [$($person.DisplayName)] could not be found by accountreference [$($actionContext.References.Account)] and is possibly deleted"
                    IsError = $true
                })
            throw "AccountNotFound"
        }
        throw $_
    }

    # Primary Contract Calculation foreach employment
    $firstProperty = @{ Expression = { $_.Details.Fte }; Descending = $true }
    $secondProperty = @{ Expression = { $_.Details.HoursPerWeek }; Descending = $true }
    $thirdProperty = @{ Expression = { $_.Details.Sequence }; Descending = $true }
    $fourthProperty = @{ Expression = { $_.EndDate }; Descending = $true }
    $fifthProperty = @{ Expression = { $_.StartDate }; Descending = $false }
    $sixthProperty = @{ Expression = { $_.ExternalId }; Descending = $false }

    # Priority Calculation Order (High priority -> Low priority)
    $splatSortObject = @{
        Property = @(
            $firstProperty,
            $secondProperty,
            $thirdProperty,
            $fourthProperty,
            $fifthProperty,
            $sixthProperty)
    }

    [array]$desiredContracts = $personContext.Person.Contracts | Where-Object { $_.Context.InConditions -eq $true -or $actionContext.DryRun -eq $true }

    if ($desiredContracts.length -lt 1) {
        # no contracts in scope found
        throw 'No Contracts in scope [InConditions] found!'
    }
    else {
        # multiple contracts in scope found
        $primaryContract = $desiredContracts | Sort-Object @splatSortObject | Select-Object -First 1
        $disciplineSearchValue = $primaryContract.Title.ExternalId
        $account.Position = $primaryContract.Title.Name
    }

    # set dynamic values
    $mapping = Import-Csv "$($config.MappingFile)" -Delimiter ";" -Encoding Default

    Write-Verbose "searching for value $($disciplineSearchValue) in field : $($disciplineSearchField)"
    $mappedObject = $mapping | Where-Object { $_.$disciplineSearchField -eq $disciplineSearchValue }
    $account.Discipline = $mappedObject.Discipline

    # Ysis-initials are mandatory but immutable, so set Ysis-Initials to existing
    $account.YsisInitials = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials

    $previousAccount = [PSCustomObject]@{
        AgbCode              = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.agbCode
        BigNumber            = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.bigNumber
        Discipline           = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline
        YsisInitials         = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials
        Email                = $currentAccount.Emails.Value
        Gender               = $currentAccount.gender
        FamilyName           = $currentAccount.name.familyName
        GivenName            = $currentAccount.name.givenName
        Infix                = $currentAccount.name.infix
        Initials             = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.initials
        EmployeeNumber       = $currentAccount.'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User'.employeeNumber
        Position             = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.position
        MobilePhone          = ($($currentAccount.phoneNumbers) | Where-Object Type -eq 'mobile').value
        WorkPhone            = ($($currentAccount.phoneNumbers) | Where-Object Type -eq 'work').value
        UserName             = $currentAccount.userName
        exportTimelineEvents = $currentAccount.exportTimelineEvents
    }

    # Extra logic needs to be implemented when the username needs to be renamed when updating
    # Set Username to existing if it already exists (case-sensitive in Ysis)
    # if ($account.userName -ieq $currentAccount.userName) {
    #     $account.userName = $currentAccount.userName
    # }
    $account.userName = $currentAccount.userName # Do not rename the username

    # Ysis account model mapping    # Discipline is immutable, so set Discipline to existing. When discipline is changed, notification will be send.
    $ysisAccount = [PSCustomObject]@{
        schemas                                                      = @('urn:ietf:params:scim:schemas:core:2.0:User', 'urn:ietf:params:scim:schemas:extension:ysis:2.0:User', 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User')
        userName                                                     = $account.UserName
        name                                                         = [PSCustomObject]@{
            familyName = $account.FamilyName
            givenName  = $account.GivenName
            infix      = $account.Infix
        }
        active                                                       = $currentAccount.active
        gender                                                       = $account.Gender
        exportTimelineEvents                                         = $currentAccount.exportTimelineEvents
        emails                                                       = @(
            [PSCustomObject]@{
                value = $account.Email # Use value from mapping
                #value = $currentAccount.Emails.Value # Use current value in Ysis
            }
        )
        phoneNumbers                                                 = @(
            [PSCustomObject]@{
                type  = 'work'
                #value = $account.WorkPhone # Use value from mapping
                value = (($currentAccount.phoneNumbers) | where-object  type -eq "work").value # Use current value in Ysis
            },
            [PSCustomObject]@{
                type  = 'mobile'
                #value = $account.MobilePhone # Use value from mapping
                value = (($currentAccount.phoneNumbers) | where-object  type -eq "mobile").value # Use current value in Ysis
            }
        )
        roles                                                        = $currentAccount.roles
        entitlements                                                 = $currentAccount.entitlements
        'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'       = [PSCustomObject]@{
            ysisInitials = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials
            discipline   = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline
            #agbCode      = $account.AgbCode # Use value from mapping
            agbCode      = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.agbCode # Use current value in Ysis
            initials     = $account.Initials
            #bigNumber    = $account.BigNumber # Use value from mapping
            bigNumber    = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.bigNumber # Use current value in Ysis
            position     = $account.Position
            modules      = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules
        }
        "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" = [PSCustomObject]@{
            employeeNumber = $account.EmployeeNumber
        }
    }

    if ([string]::IsNullOrEmpty($account.Discipline)) {
        Write-Warning "Discipline mapping not found for [$($account.Position)] [$disciplineSearchValue]"
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "UpdateAccount"
                Message = "Failed to update account [$($account.UserName)]: No entry found in discipline mapping for title [$($account.Position)] with externalId [$disciplineSearchValue]"
                IsError = $true
            })
    }

    if ($mappedObject.Count -gt 1) {
        Write-Warning "Multiple discipline-mappings found for [$($account.Position)] [$disciplineSearchValue]"
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "UpdateAccount"
                Message = "Failed to update account [$($account.UserName)]: Multiple entries found in discipline mapping for title [$($account.Position)] with externalId [$disciplineSearchValue]: [$($mappedObject.Discipline -join ", ")]"
                IsError = $true
            })
    }
    if ($outputContext.AuditLogs.isError -contains $true) {
        Throw "Error(s) occured while looking up required values"
    }

    # Calculate changes between current data and provided data
    $splatCompareProperties = @{
        ReferenceObject  = @($previousAccount.PSObject.Properties) # Only select the properties to update
        DifferenceObject = @($account.PSObject.Properties) # Only select the properties to update
    }
    $changedProperties = $null
    $changedProperties = (Compare-Object @splatCompareProperties -PassThru)
    $newProperties = $changedProperties.Where( { $_.SideIndicator -eq '=>' })

    if (($newProperties | Measure-Object).Count -ge 1) {
        Write-Verbose "Updating Ysis account with accountReference: [$($actionContext.References.Account)]"
        $splatUpdateUserParams = @{
            Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($actionContext.References.Account)"
            Headers     = $headers
            Method      = 'PUT'
            Body        = $ysisaccount | ConvertTo-Json
            ContentType = 'application/scim+json;charset=UTF-8'
        }
        if (-not($actionContext.DryRun -eq $true)) {
            $null = Invoke-RestMethod @splatUpdateUserParams -Verbose:$false
        }
        else {
            Write-Warning "[DryRun] Will send: $($splatCreateUserParams.Body)"
        }

        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "UpdateAccount"
                Message = "Account with Ysis Initials [$($account.ysisInitials)] and username [$($account.UserName)] updated"
                IsError = $false
            })
    }
    else {
        Write-Information "No Updates for Ysis account with username [$($account.userName)] and accountReference [$($actionContext.References.Account)]"
    }
}
catch {
    $ex = $PSItem
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Warning $_
    }
    if (-not($ex.Exception.Message -eq 'AccountNotFound' -or $ex.Exception.Message -eq 'Error(s) occured while looking up required values')) {
        if ($($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
            $errorObj = Resolve-YsisError -ErrorObject $ex
            $auditMessage = "Could not update Ysis account. Error: $($errorObj.FriendlyMessage)"
            Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        }
        else {
            $auditMessage = "Could not update Ysis account. Error: $($ex.Exception.Message)"
            Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        }
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "UpdateAccount"
                Message = $auditMessage
                IsError = $true
            })
    }
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-not($outputContext.AuditLogs.IsError -contains $true)) {
        $outputContext.Success = $true
    }

    # add ID to export data
    $account | Add-Member -MemberType NoteProperty -Name id -Value $actionContext.References.Account -Force
    $outputContext.Data = $account
    $outputContext.PreviousData = $previousAccount
}