########################################
# HelloID-Conn-Prov-Target-Ysis-Create
# PowerShell V2
########################################

# Initialize default values
$config = $actionContext.Configuration
$person = $personContext.Person
$disciplineSearchField = "JobTitleId" # fieldname in CSV

$outputContext.AccountReference = 'Currently not available'

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($actionContext.Configuration.isDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
function Set-YsisInitials-Iteration {
    # Generates Unique Ysis initials:
    # # first two characters lastname + first twee characters nickname (as set in the mapping)
    # # If not unique, then use logic below (first three letters nickname, then 4, etc)
    # # When all options are exhausted, add an iterator to the ysisInitials in the mapping
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
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
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
            $httpErrorObj.ErrorDetails = "Message: $($errorDetailsObject.detail), type: $($errorDetailsObject.scimType)"
            $httpErrorObj.FriendlyMessage = "$($errorDetailsObject.detail), type: $($errorDetailsObject.scimType)"
        } catch {
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
        }
        Write-Output $httpErrorObj
    }
}
#endregion functions


try {
    # Create account object from mapped data and set the correct account reference
    $account = $actionContext.Data

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

    [array]$desiredContracts = $personContext.Person.Contracts | Where-Object { $_.Context.InConditions -eq $true -or $actionContext.DryRun -eq $true }

    if ($desiredContracts.length -lt 1) {
        # no contracts in scope found
        throw "No contracts are in scope for person [$($person.DisplayName)]"
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
            modules      = @()
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
                Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
            }
            else {
                $auditMessage = "Could not retrieve Ysis Token. Error: $($ex.Exception.Message)"
                Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
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
            $auditMessage = "Multiple users found for [$($person.DisplayName)] with correlationValue [($correlationValue)]: [$($response.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials -join ", ")]"
            Throw $auditMessage
        }
        elseif (($response | measure-object).count -eq 1) {
            $correlatedAccount = $response
        }
        else {
            $correlatedAccount = $null
        }

        if ($null -ne $correlatedAccount) {
            Write-Verbose "Ysis account correlated for [$($person.DisplayName)] with correlationValue [$correlationValue] and ysisInitials [$($correlatedAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials)] [$($correlatedAccount.id)]"

            $outputContext.AccountReference = $correlatedAccount.id

            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CorrelateAccount"
                    Message = "Account with Ysis Initials [$($correlatedAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials)] and username [$($ysisAccount.userName)] correlated on field [$($correlationField)] with value [$($correlationValue)]"
                    IsError = $false
                })

                # Update is handled in the update script
                $outputContext.AccountCorrelated = $True
        }
    }

    if (-not $outputContext.AccountCorrelated -and $null -eq $correlatedAccount) {

        if ([string]::IsNullOrEmpty($disciplineSearchValue)) {
            Write-Warning "No discipline mapping for found in csv for title [$($account.Position)]"
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount"
                    Message = "Failed to create account with username [$($account.UserName)]: No discipline mapping for found in csv for title [$($account.Position)]"
                    IsError = $true
                })
        }

        if ([string]::IsNullOrEmpty($account.employeeNumber)) {
            Write-Warning "No employeenumber mapped for account"
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Failed to create account with username [$($account.UserName)]: No employeenumber mapped for account"
                IsError = $true
            })
        }

        if ([string]::IsNullOrEmpty($account.Discipline)) {
            Write-Warning "No entry found in the discipline mapping found for title [$($account.Position)] with externalId [$disciplineSearchValue]"
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Failed to create account with username [$($account.UserName)]: No entry found in discipline mapping for title [$($account.Position)] with externalId [$disciplineSearchValue]"
                IsError = $true
            })
        }

        if ($mappedObject.Count -gt 1) {
            Write-Warning "Multiple entries found in discipline mapping for title [$($account.Position)] with externalId [$disciplineSearchValue]: [$($mappedObject.Discipline -join ", ")]"
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Failed to create account with username [$($account.UserName)]: Multiple entries found in discipline mapping for title [$($account.Position)] with externalId [$disciplineSearchValue]: [$($mappedObject.Discipline -join ", ")]"
                IsError = $true
            })
        }
        if ($outputContext.AuditLogs.isError -contains $true) {
            Throw "Error(s) occured while looking up required values"
        }

        $maxIterations = 5
        $Iterator = 0
        $uniqueness = $false

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

                if (-not($actionContext.DryRun -eq $true)) {
                    $responseCreateUser = Invoke-RestMethod @splatCreateUserParams -Verbose:$false
                    $outputContext.AccountReference = $responseCreateUser.id
                }
                else {
                    Write-Warning "[DryRun] Will send: $($splatCreateUserParams.Body)"
                }
                $uniqueness = $true

                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Action  = "CreateAccount"
                        Message = "Account with Ysis Initials [$($account.ysisInitials)] and username [$($account.UserName)] created"
                        IsError = $false
                    })

            }
            catch {
                $ex = $PSItem
                $errorObj = Resolve-YsisError -ErrorObject $ex
                Write-Verbose "$Iterator : $($_.Exception.Response.StatusCode) - $($errorObj.FriendlyMessage)"

                if ($_.Exception.Response.StatusCode -eq 'Conflict' -and $($errorObj.FriendlyMessage) -match "A user with the 'ysisInitials'") {
                    $Iterator++
                    Write-Warning "Ysis-Initials in use, trying with [$($ysisAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials)]"
                }
                else {
                    throw $_
                }
            }
        } while ($uniqueness -ne $true -and $Iterator -lt $maxIterations)

        if (-not($uniqueness -eq $true)) {
            throw "A user with the 'ysisInitials' '$($ysisAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials)' already exists. YSIS-Initials out of iterations"
        }

        if ($actionContext.DryRun -eq $true) {
            Write-Warning "[DryRun] Account with username [$($account.UserName)] and discipline [$($mappedObject.Discipline)] will be created."
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount"
                    Message = "[DryRun] Account with username [$($account.UserName)] and discipline [$($mappedObject.Discipline)] will be created."
                    IsError = $false
                })
        }

        # add ID to export data
        $account | Add-Member -MemberType NoteProperty -Name id -Value $responseCreateUser.id -Force
    }
}
catch {
    $ex = $PSItem
    if (-not($ex.Exception.Message -eq 'Token error' -or $ex.Exception.Message -eq 'Error(s) occured while looking up required values')) {
        if ($($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
            $errorObj = Resolve-YsisError -ErrorObject $ex
            $auditMessage = "Could not create Ysis account. Error: $($errorObj.FriendlyMessage)"
            Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        }
        else {
            $auditMessage = "Could not create Ysis account. Error: $($ex.Exception.Message)"
            Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        }
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
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

    $outputContext.Data = $account
}
