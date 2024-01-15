########################################
# HelloID-Conn-Prov-Target-YsisV2-Create
#
# Version: 2.0.0
########################################

# Initialize default values
$config = $actionContext.Configuration
$outputContext.success = $false;

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = "Continue" }
    $false { $VerbosePreference = "SilentlyContinue" }
}
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# Create account object from mapped data and set the correct account reference
$account = $actionContext.Data;
$person = $personContext.Person;

$disciplineSearchField = "JobTitleId";
$disciplineSearchValue = $personContext.Person.PrimaryContract.Title.Code

# set dynamic values
$mapping = Import-Csv "$($config.MappingFile)" -Delimiter ";"
$mappedObject = $mapping | Where-Object { $_.$disciplineSearchField -eq $disciplineSearchValue }
$account.Discipline = $mappedObject.Discipline

#Ysis account model mapping
$Ysisaccount = [PSCustomObject]@{
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
        ysisInitials = ''
        discipline   = $account.Discipline
        agbCode      = $account.AgbCode
        initials     = $account.Initials
        bigNumber    = $account.BigNumber
        position     = $account.Position
        modules      = @('YSIS_CORE')        
    }
    "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" = [PSCustomObject]@{
        employeeNumber = $account.EmployeeNumber
    }
    password                                                     = $account.Password
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
                    $tempInitials = $YsisInitials
                    break 
                }
                default {        
                    $tempInitials = $YsisInitials
                    $suffix = "$($Iteration+1)"
                }
            }
            $result = ("{0}{1}" -f $tempInitials, $suffix)
            $result = $result.ToUpper()
            
            Write-Output $result
        }
        catch {
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount" # Optionally specify a different action for this audit log
                    Message = "An error was found in the ysisinitials iteration algorithm: $($_.Exception.Message): $($_.ScriptStackTrace)"
                    IsError = $true
                })
        } 
    }
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

#Use of mapping in target-connector instead of source-enrichment
function Set-AccountDisciplineByMapping {
    [cmdletbinding()]
    Param (
        [object]$account,
        [object]$mappedObject
    )    
    $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.Discipline = $mappedObject.Discipline    
}

function Set-AccountRoleByMapping {
    [cmdletbinding()]
    Param (
        [object]$account,
        [object]$mappedObject
    )    
    # Set Role
    $splatRoleParams = @{
        Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/roles"
        Method      = 'GET'
        Headers     = $headers
        ContentType = 'application/json'
    }
    $roles = Invoke-RestMethod @splatRoleParams -Verbose:$false

    $role = [pscustomobject]@(
        @{
            displayName = $mappedObject.Description;
            value       = ($roles | Where-Object displayName -eq $($mappedObject.Description)).value
        })    
    $account.roles += $role
}
#endregion functions

# Check if we should try to correlate the account
if ($actionContext.CorrelationConfiguration.Enabled) {
    $correlationField = $actionContext.CorrelationConfiguration.accountField
    $correlationValue = $actionContext.CorrelationConfiguration.accountFieldValue

    if ($null -eq $correlationField) {
        Write-Warning "Correlation is enabled but not configured correctly."
    }

    # Write logic here that checks if the account can be correlated in the target system
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
    Write-Verbose "Verifying if YsisV2 account for [$($person.DisplayName) ($correlationValue)] exists"        
    $encodedString = [System.Uri]::EscapeDataString($correlationValue)
    
    $splatParams = @{
        Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users?filter=urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:employeeNumber%20eq%20%22$encodedString%22"
        Method      = 'GET'
        Headers     = $headers
        ContentType = 'application/json'
    }
    $response = Invoke-RestMethod @splatParams -Verbose:$false
    $correlatedAccount = $response | Select-Object -First 1

    if ($null -ne $correlatedAccount) {        
        $outputContext.AccountReference = $correlatedAccount.id        

        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "CorrelateAccount" # Optionally specify a different action for this audit log
                Message = "Correlated account with username $($correlatedAccount.UserName) on field $($correlationField) with value $($correlationValue)"
                IsError = $false
            })
        
        $outputContext.Success = $True   
        if ($actionContext.Configuration.UpdatePersonOnCorrelate -eq 'True') {     
            $outputContext.AccountCorrelated = $True        
        }
    }
}

if (!$outputContext.AccountCorrelated -and $null -eq $correlatedAccount) {
    # Create account object from mapped data and set the correct account reference
    $incompleteAccount = $false

    if ([string]::IsNullOrEmpty($disciplineSearchValue)) {
        $incompleteAccount = $true
        $message = "No mapping has been found discipline on [$($account.Position)]."
        Write-Warning "No mapping has been found discipline on [$($account.Position)]."
    }

    if ([string]::IsNullOrEmpty($account.employeeNumber)) {
        $incompleteAccount = $true
        $message = "Person does not has a employeenumber"
        Write-Warning "Person does not has a employeenumber"
    }

    if ($null -eq $mappedObject) {    
        $incompleteAccount = $true
        $message = "No discipline-mapping found for [$($account.Position)]"            
        Write-Warning "No discipline-mapping found for [$($account.Position)]"            
    }

    if ($mappedObject.Count -gt 1) {
        $incompleteAccount = $true
        $message = "Multiple discipline-mappings found for [$($account.Position)]"            
        Write-Warning "Multiple discipline-mappings found for [$($account.Position)]"            
    }

    if ($incompleteAccount) {
        $outputContext.Success = $false
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount" # Optionally specify a different action for this audit log
                Message = "Failed to create account with username $($account.UserName), due to incomplete account. $message"
                IsError = $true
            })     
    }
    else {        
        Set-AccountDisciplineByMapping -account $ysisaccount -mappedObject $mappedObject
        Set-AccountRoleByMapping -account $ysisaccount -mappedObject $mappedObject
        
        if (-Not($actionContext.DryRun -eq $true)) {            
            # Write create logic here
            $maxIterations = 5
            $Iterator = 0
            $uniqueness = $false
            
            try {
                do {
                    # Add initials to the account object.
                    $ysisaccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials = Set-YsisInitials-Iteration -YsisInitials $($account.ysisInitials) -Iteration $Iterator
            
                    try {
                        $splatCreateUserParams = @{
                            Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users"
                            Headers     = $headers
                            Method      = 'POST'
                            Body        = $ysisaccount | ConvertTo-Json
                            ContentType = 'application/scim+json;charset=UTF-8'
                        }
                    
                        $responseCreateUser = Invoke-RestMethod @splatCreateUserParams -Verbose:$false
                        $uniqueness = $true
                    
                        $outputContext.AccountReference = $responseCreateUser.id
                        $outputContext.Success = $true

                        $outputContext.AuditLogs.Add([PSCustomObject]@{
                                Action  = "CreateAccount" # Optionally specify a different action for this audit log
                                Message = "Created account with username $($account.UserName)"
                                IsError = $false
                            })
                    
                    }
                    catch {             
                        $ex = $PSItem          
                        $errorObj = Resolve-YsisV2Error -ErrorObject $ex 
                        if ($_.Exception.Response.StatusCode -eq 'Conflict' -and $($errorObj.FriendlyMessage) -match "A user with the 'ysisInitials'") {                        
                            $Iterator++
                            Write-Warning "YSIS-Initials in use, trying with [$($account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials)]."                            
                        }
                        else {
                            throw $_                            
                        }
                    }
                } while ($uniqueness -ne $true -and $Iterator -lt $maxIterations)
                if (!($uniqueness -eq $true)) {
                    throw "A user with the 'ysisInitials' '$($account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials)' already exists. YSIS-Initials out of iterations!"                      
                }            
            }
            catch {
                $ex = $PSItem
                if ($($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
                    $errorObj = Resolve-YsisV2Error -ErrorObject $ex
                    $auditMessage = "Could not create YsisV2 account. Error: $($errorObj.FriendlyMessage)"
                    Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
                }
                else {
                    $auditMessage = "Could not create YsisV2 account. Error: $($ex.Exception.Message)"
                    Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
                }
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Action  = "CreateAccount" # Optionally specify a different action for this audit log
                        Message = $auditMessage
                        IsError = $true
                    })
            }        
        }    
        if ($actionContext.DryRun -eq $true) {
            $outputContext.AccountReference = "DRYRUN"
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount" # Optionally specify a different action for this audit log
                    Message = "Account with username [$($account.UserName)] and discipline [$($mappedObject.Discipline)] will be created."
                    IsError = $false
                })
        }
        $outputContext.Data = $account 
    }
}
