########################################
# HelloID-Conn-Prov-Target-Ysis-Create
# PowerShell V2
########################################

# Initialize default values
$config = $actionContext.Configuration
$outputContext.AccountReference = "DRYRUN"

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($actionContext.Configuration.isDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
function Set-YsisInitials-Iteration {
    [cmdletbinding()]
    Param (
        [string]$YsisInitials,
        [int]$Iteration
    )
    Process {
        try {
            switch ($Iteration) {
                0 {
                    $tempInitials = $ysisInitials
                    break
                }
                default {
                    if ($Person.Name.NickName.Length -ge ($iteration + 2)) {
                        $nickNameExtraChars = $Person.Name.NickName.substring(2, $iteration)
                        $tempInitials = ("{0}{1}" -f $ysisInitials, $nickNameExtraChars)
                    }
                    else {
                        $tempInitials = $ysisInitials
                        $suffix = "$($Iteration+1)"
                    }
                }
            }

            $result = ("{0}{1}" -f $tempInitials, $suffix)
            $result = $result.ToUpper()
            Write-Output $result
        }
        catch {
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount"
                    Message = "An error was found in the ysisinitials iteration algorithm: $($_.Exception.Message): $($_.ScriptStackTrace)"
                    IsError = $true
                })
        }
    }
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

#endregion functions


try {
    # Create account object from mapped data and set the correct account reference
    $account = $actionContext.Data
    $person = $personContext.Person

    $disciplineSearchField = "JobTitleId"

    # Remove ID field because only used for export data
    if ($account.PSObject.Properties.Name -Contains 'id') {
        $account.PSObject.Properties.Remove('id')
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
        throw "No contracts are in scope for person [$($account.IdentificationNo)],should not happen!"
    }
    else {
        # contracts in scope found
        $primaryContract = $desiredContracts | Sort-Object @splatSortObject | Select-Object -First 1
        $disciplineSearchValue = $primaryContract.Title.ExternalId
        $account.Position = $primaryContract.Title.Name
    }

    # set dynamic values
    $mapping = Import-Csv "$($config.MappingFile)" -Delimiter ";" -Encoding Default
    Write-Verbose "Searching within the mapping csv for value [$($disciplineSearchValue)] in field [$($disciplineSearchField)]"
    $mappedObject = $mapping | Where-Object { $_.$disciplineSearchField -eq $disciplineSearchValue }
    $account.Discipline = $mappedObject.Discipline

    #Ysis account model mapping
    $ysisAccount = [PSCustomObject]@{
        schemas                                                      = @('urn:ietf:params:scim:schemas:core:2.0:User', 'urn:ietf:params:scim:schemas:extension:ysis:2.0:User', 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User')
        userName                                                     = $account.UserName
        name                                                         = [PSCustomObject]@{
            givenName  = $account.GivenName
            familyName = $account.FamilyName
            infix      = $account.Infix
        }
        gender                                                       = $account.Gender
        emails                                                       = @(
            [PSCustomObject]@{
                value   = $account.Email
                type    = 'work'
                primary = $true
            }
        )
        exportTimelineEvents                                         = $false
        roles                                                        = @()
        entitlements                                                 = @()
        phoneNumbers                                                 = @(
            [PSCustomObject]@{
                value = $account.WorkPhone
                type  = 'work'
            },
            [PSCustomObject]@{
                value = $account.MobilePhone
                type  = 'mobile'
            }
        )
        'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'       = [PSCustomObject]@{
            ysisInitials = ''   # Filled in later
            discipline   = $account.Discipline
            agbCode      = $account.AgbCode
            initials     = $account.Initials
            bigNumber    = $account.BigNumber
            position     = $account.Position
            modules      = @($config.DefaultModule)
        }
        "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" = [PSCustomObject]@{
            employeeNumber = $account.EmployeeNumber
        }
        password                                                     = $account.Password
    }

    # Check if we should try to correlate the account
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.accountField
        $correlationValue = $actionContext.CorrelationConfiguration.accountFieldValue

        if ($null -eq $correlationField) {
            Write-Warning "Correlation is enabled but not configured correctly."
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

        try {
            $responseAccessToken = Invoke-RestMethod @splatRequestToken -Verbose:$false
        }
        catch {
            write-error "$($_)"
            $ex = $PSItem
            if ($($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
                $errorObj = Resolve-YsisError -ErrorObject $ex
                $auditMessage = "Could not retrieve Ysis Token. Error: $($errorObj.FriendlyMessage)"
                Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
            }
            else {
                $auditMessage = "Could not retrieve Ysis Token. Error: $($ex.Exception.Message)"
                Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
            }
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount"
                    Message = $auditMessage
                    IsError = $false
                })
            throw "Token error"
        }

        $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
        $headers.Add('Authorization', "Bearer $($responseAccessToken.access_token)")
        $headers.Add('Accept', 'application/json; charset=utf-8')
        $headers.Add('Content-Type', 'application/json')

        # Verify if a user must be either [created and correlated], [updated and correlated] or just [correlated]
        Write-Verbose "Verifying if Ysis account for [$($person.DisplayName) - (correlationValue: $correlationValue)] exists"
        $encodedString = [System.Uri]::EscapeDataString($correlationValue)

        $splatParams = @{
            Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users?filter=urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:employeeNumber%20eq%20%22$encodedString%22"
            Method      = 'GET'
            Headers     = $headers
            ContentType = 'application/json'
        }
        $response = Invoke-RestMethod @splatParams -Verbose:$false

        if (($response | measure-object).count -gt 1) {
            $auditMessage = "multiple users found for $($person.DisplayName) with correlationValue: [($correlationValue)] - $($response.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials -join(","))"
            Throw $auditMessage
        }
        elseif (($response | measure-object).count -eq 1) {
            $correlatedAccount = $response
        }
        else {
            $correlatedAccount = $null
        }

        if ($null -ne $correlatedAccount) {
            Write-Verbose "correlation found in Ysis for [$($person.DisplayName) ($correlationValue)] with ysisInitials $($correlatedAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials) [$($correlatedAccount.id)]"   

            $outputContext.AccountReference = $correlatedAccount.id

            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CorrelateAccount"
                    Message = "Correlated account with username $($correlatedAccount.UserName) on field $($correlationField) with value $($correlationValue)"
                    IsError = $false
                })

            if ($actionContext.Configuration.UpdatePersonOnCorrelate -eq 'True') {
                $outputContext.AccountCorrelated = $True
            }
            else {
                $account.ysisInitials = $correlatedAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials
                $account.Discipline = $correlatedAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.Discipline
            }
        }
    }

    if (!$outputContext.AccountCorrelated -and $null -eq $correlatedAccount) {
        #Validation:
        if ([string]::IsNullOrEmpty($disciplineSearchValue)) {
            Write-Warning "No externalId found for found title [$($account.Position)]"
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount" # Optionally specify a different action for this audit log
                    Message = "Failed to create account with username $($account.UserName): No discipline mapping for found in csv for title [$($account.Position)]"
                    IsError = $true
                })
        }

        if ([string]::IsNullOrEmpty($account.employeeNumber)) {
            Write-Warning "Person does not has a employeenumber"
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount" # Optionally specify a different action for this audit log
                Message = "Failed to create account with username $($account.UserName): No employeenumber mapped for account"
                IsError = $true
            })
        }

        if ([string]::IsNullOrEmpty($account.Discipline)) {
            Write-Warning "Discipline mapping not found for [$($account.Position)] [$disciplineSearchValue]"
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount" # Optionally specify a different action for this audit log
                Message = "Failed to create account with username $($account.UserName): No entry found in the discipline mapping found for title: [$($account.Position)] with externalId: [$disciplineSearchValue]"
                IsError = $true
            })
        }

        if ($mappedObject.Count -gt 1) {
            Write-Warning "Multiple discipline-mappings found for [$($account.Position)] [$disciplineSearchValue]"
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount" # Optionally specify a different action for this audit log
                Message = "Failed to create account with username $($account.UserName): Multiple entries found in the discipline mapping found for title: [$($account.Position)] with externalId: [$disciplineSearchValue]"
                IsError = $true
            })
        }
        if ($outputContext.AuditLogs.isError -contains $true) {
            Throw "Error(s) occured while looking up required values"
        }

        $maxIterations = 5
        $Iterator = 0
        $uniqueness = $false

        try {
            do {
                $ysisAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials = Set-YsisInitials-Iteration -YsisInitials $($account.ysisInitials) -Iteration $Iterator

                try {
                    $splatCreateUserParams = @{
                        Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users"
                        Headers     = $headers
                        Method      = 'POST'
                        Body        = $ysisAccount | ConvertTo-Json
                        ContentType = 'application/scim+json;charset=UTF-8'
                    }

                    if (-Not($actionContext.DryRun -eq $true)) {
                        $responseCreateUser = Invoke-RestMethod @splatCreateUserParams -Verbose:$false
                    }
                    else {
                        Write-Warning "will send: $($splatCreateUserParams.Body)"
                    }
                    $uniqueness = $true

                    $outputContext.AccountReference = $responseCreateUser.id

                    $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Action  = "CreateAccount"
                            Message = "Created account with username $($account.UserName)"
                            IsError = $false
                        })

                }
                catch {
                    $ex = $PSItem
                    $errorObj = Resolve-YsisError -ErrorObject $ex
                    Write-Warning "$Iterator : $($_.Exception.Response.StatusCode) - $($errorObj.FriendlyMessage)"

                    if ($_.Exception.Response.StatusCode -eq 'Conflict' -and $($errorObj.FriendlyMessage) -match "A user with the 'ysisInitials'") {
                        $Iterator++
                        Write-Warning "YSIS-Initials in use, trying with [$($account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials)]."
                    }
                    else {
                        throw $_
                    }
                }
            } while ($uniqueness -ne $true -and $Iterator -lt $maxIterations)
            if (-not($uniqueness -eq $true)) {
                throw "A user with the 'ysisInitials' '$($account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials)' already exists. YSIS-Initials out of iterations"
                if ($actionContext.DryRun -eq $true) {

                    Write-Warning "Account with username [$($account.UserName)] and discipline [$($mappedObject.Discipline)] will be created."
                    $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Action  = "CreateAccount"
                            Message = "Account with username [$($account.UserName)] and discipline [$($mappedObject.Discipline)] will be created."
                            IsError = $false
                        })
                }

                # add ID to export data
                $account | Add-Member -MemberType NoteProperty -Name id -Value $responseCreateUser.id -Force
                # $outputContext.Data = $account
            }
        }
        catch {
            $ex = $PSItem
            if ($($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
                $errorObj = Resolve-YsisError -ErrorObject $ex
                $auditMessage = "Could not create Ysis account. Error: $($errorObj.FriendlyMessage)"
                Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
            }
            else {
                $auditMessage = "Could not create Ysis account. Error: $($ex.Exception.Message)"
                Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
            }
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount" # Optionally specify a different action for this audit log
                    Message = $auditMessage
                    IsError = $true
                })
        }

        if ($actionContext.DryRun -eq $true) {
            Write-Warning "Account with username [$($account.UserName)] and discipline [$($mappedObject.Discipline)] will be created."
        }
    }
}
catch {
    $ex = $PSItem
    if (-Not($ex.Exception.Message -eq 'Token error' -or $ex.Exception.Message -eq 'Error(s) occured while looking up required values')) {
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
                Action  = "UpdateAccount" # Optionally specify a different action for this audit log
                Message = $auditMessage
                IsError = $true
            })
    }
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-NOT($outputContext.AuditLogs.IsError -contains $true)) {
        $outputContext.Success = $true
    }

    $outputContext.Data = $account
}