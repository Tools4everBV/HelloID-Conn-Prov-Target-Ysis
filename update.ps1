########################################
# HelloID-Conn-Prov-Target-YsisV2-Update
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

try {
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
    $headers.Add('Accept', 'application/json')
    $headers.Add('Content-Type', 'application/json')

    Write-Verbose "Verifying if YsisV2 account for [$($person.DisplayName)] exists"
    try {
        $splatParams = @{
            Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($actionContext.References.Account)"
            Headers     = $headers
            ContentType = 'application/json'
        }
        $currentAccount = Invoke-RestMethod @splatParams -Verbose:$false     
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            $auditLogs.Add([PSCustomObject]@{
                    Message = "YsisV2 account for: [$($person.DisplayName)] not found. Possibly deleted"
                    IsError = $false
                })
        }
        throw
    }
}
catch {        
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
}

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
}

# Set Username to existing (case-sensitive in Ysis)
if($account.userName -ieq $currentAccount.userName) {        
    $account.userName = $currentAccount.userName
}

# Ysis account model mapping
# Roles are based on discipline and discipline can't be changed, so set Roles to existing    
# Modules could be changed manually, so set Modules to existing
# Discipline is immutable, so set Discipline to existing. When discipline is changed, notification will be send.

$ysisaccount = [PSCustomObject]@{
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
            value = $account.WorkPhone
        },
        [PSCustomObject]@{
            type  = 'mobile'
            value = $account.MobilePhone
        }
    )
    roles                                                        = $currentAccount.roles
    entitlements                                                 = @()
    'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'       = [PSCustomObject]@{
        ysisInitials = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials
        discipline   = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline
        agbCode      = $account.AgbCode
        initials     = $account.Initials
        bigNumber    = $account.BigNumber
        position     = $account.Position        
        modules      = $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules
    }
    "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" = [PSCustomObject]@{
        employeeNumber = $account.EmployeeNumber
    }    
}

if (-Not($actionContext.DryRun -eq $true)) {    
    # Write update logic here
    try {        
        if ($null -eq $mappedObject) {            
            throw "No discipline-mapping found for [$($account.Position)]"                            
        }

        if ($mappedObject.Count -gt 1) {
            
            throw "Multiple discipline-mappings found for [$($account.Position)]"                    
        }
        
        Write-Verbose "Updating YsisV2 account with accountReference: [$($actionContext.References.Account)]"
        $splatUpdateUserParams = @{
            Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($actionContext.References.Account)"
            Headers     = $headers
            Method      = 'PUT'
            Body        = $ysisaccount | ConvertTo-Json
            ContentType = 'application/scim+json;charset=UTF-8'
        }

        $null = Invoke-RestMethod @splatUpdateUserParams -Verbose:$false

        $outputContext.Success = $true
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "UpdateAccount" # Optionally specify a different action for this audit log
                Message = "Account with username $($account.userName) updated"
                IsError = $false
            })
            
    }
    catch {        
        $outputContext.Success = $false
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
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "UpdateAccount" # Optionally specify a different action for this audit log
                Message = $auditMessage
                IsError = $true
            })
    }    
}

$outputContext.Data = $account
$outputContext.PreviousData = $previousAccount
