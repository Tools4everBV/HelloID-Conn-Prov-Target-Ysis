#################################################
# HelloID-Conn-Prov-Target-Ysis-Update
# PowerShell V2
#################################################

# Initialize default values
$config = $actionContext.Configuration
$outputContext.success = $false

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

try {
    # Create account object from mapped data and set the correct account reference
    $account = $actionContext.Data
    $person = $personContext.Person

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

    Write-Verbose 'Adding Authorization headers'
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
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "UpdateAccount"
                    Message = "Ysis account for: [$($person.DisplayName)] not found. Possibly deleted"
                    IsError = $true
                })
            throw "Possibly deleted"
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
    
    $contracts = $personContext.Person.Contracts

    [array]$desiredContracts = $contracts | Where-Object { $_.Context.InConditions -eq $true -or $actionContext.DryRun -eq $true }

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

    $disciplineSearchField = "JobTitleId" # Move to top?

    # set dynamic values
    $mapping = Import-Csv "$($config.MappingFile)" -Delimiter ";" -Encoding Default

    Write-Verbose "searching for value $($disciplineSearchValue) in field : $($disciplineSearchField)"
    $mappedObject = $mapping | Where-Object { $_.$disciplineSearchField -eq $disciplineSearchValue }
    $account.Discipline = $mappedObject.Discipline

    # Ysis-initials are mandatory but immutable, so set Ysis-Initials to existing
    $account.YsisInitials = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials

    $previousAccount = [PSCustomObject]@{
        AgbCode        = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.agbCode
        BigNumber      = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.bigNumber
        Discipline     = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline
        YsisInitials   = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials
        Email          = $currentAccount.Emails.Value
        Gender         = $currentAccount.gender
        FamilyName     = $currentAccount.name.familyName
        GivenName      = $currentAccount.name.givenName
        Infix          = $currentAccount.name.infix
        Initials       = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.initials
        EmployeeNumber = $currentAccount.'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User'.employeeNumber
        Position       = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.position    
        MobilePhone    = ($($currentAccount.phoneNumbers) | Where-Object Type -eq 'mobile').value
        WorkPhone      = ($($currentAccount.phoneNumbers) | Where-Object Type -eq 'work').value
        UserName       = $currentAccount.userName
        roles          = ($currentAccount.roles).displayname
    }

    # Set Username to existing (case-sensitive in Ysis)
    if ($account.userName -ieq $currentAccount.userName) {        
        $account.userName = $currentAccount.userName
    }

    # Ysis account model mapping
    # Roles are based on discipline and discipline can't be changed, so set Roles to existing # <== Roles will be moved to permissions
    # Modules could be changed manually, so set Modules to existing # <== Modules will be moved to permissions, for this customer setting modules is not required
    # Discipline is immutable, so set Discipline to existing. When discipline is changed, notification will be send.

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
        emails                                                       = @(
            [PSCustomObject]@{
                value = $account.Email
            }
        )
        phoneNumbers                                                 = @(
            [PSCustomObject]@{
                type  = 'work'
                #value = $account.WorkPhone
                value = (($currentAccount.phoneNumbers) | where-object  type -eq "work").value
            },
            [PSCustomObject]@{
                type  = 'mobile'
                #value = $account.MobilePhone
                value = (($currentAccount.phoneNumbers) | where-object  type -eq "mobile").value
            }
        )
        #roles                                                        = @() #$currentAccount.roles
        roles                                                        = $currentAccount.roles 
        entitlements                                                 = $currentAccount.entitlements
        'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'       = [PSCustomObject]@{
            ysisInitials = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials
            discipline   = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline
            #agbCode      = $account.AgbCode
            agbCode      = $currentAccount.AgbCode
            initials     = $account.Initials
            #bigNumber    = $account.BigNumber
            bigNumber    = $currentAccount.BigNumber
            position     = $account.Position        
            modules      = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules
        }
        "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" = [PSCustomObject]@{
            employeeNumber = $account.EmployeeNumber
        }    
    }

    # #if not mapped use current value:
    # if (-not [bool]($account.PSobject.Properties.name -match "agbCode")) {
    #     $ysisaccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.agbCode = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.agbCode
    # }

    # #if not mapped use current value:
    # if (-not [bool]($account.PSobject.Properties.name -match "bigNumber")) {
    #     $ysisaccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.bigNumber = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.bigNumber
    # }

    if ([string]::IsNullOrEmpty($account.Discipline)) {           
        throw "No discipline-mapping found for [$($account.Position)] [$disciplineSearchValue]"                   
    }

    if ($mappedObject.Count -gt 1) {
        throw "Multiple discipline-mappings found for [$($account.Position)] [$disciplineSearchValue]"                    
    }

    #$role = Get-AccountRoleByMapping  -SearchValue $mappedObject.rol # <== moved to permission script
    # if([string]::IsNullOrEmpty($role)){
    #     Throw "Unable to find role with name: $($mappedObject.rol)"
    # }
    #$YsisAccount.roles += $role

    # Calculate changes between current data and provided data
    $splatCompareProperties = @{
        ReferenceObject  = @($previousAccount.PSObject.Properties) # Only select the properties to update
        DifferenceObject = @($account.PSObject.Properties) # Only select the properties to update
    }
    $changedProperties = $null
    $changedProperties = (Compare-Object @splatCompareProperties -PassThru)
    #$oldProperties = $changedProperties.Where( { $_.SideIndicator -eq '<=' }) # not used in script
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
        if (-Not($actionContext.DryRun -eq $true)) { 
            $null = Invoke-RestMethod @splatUpdateUserParams -Verbose:$false
        }
        else {
            Write-warning "send: $($splatUpdateUserParams.body)" 
        }

        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "UpdateAccount"
                Message = "Account with username $($account.userName) updated"
                IsError = $false
            })
    }
    else {
        Write-Verbose "No Updates for Ysis account with accountReference: [$($actionContext.References.Account)]"
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "UpdateAccount"
                Message = "Account with username $($account.userName) has no updates"
                IsError = $false
            })
    }    
}
catch {        
    $ex = $PSItem
    if (-Not($ex.Exception.Message -eq 'Possibly deleted')) {
        if ($($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
            $errorObj = Resolve-YsisError -ErrorObject $ex
            $auditMessage = "Could not update Ysis account. Error: $($errorObj.FriendlyMessage)"
            Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        }
        else {
            $auditMessage = "Could not update Ysis account. Error: $($ex.Exception.Message)"
            Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
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