########################################
# HelloID-Conn-Prov-Target-YsisV2-Enable
#
# Version: 2.0.0
########################################
# Initialize default values
$config = $actionContext.Configuration
$p = $personContext.Person
$outputContext.Success = $false

#region functions
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
#endregion functions
#$actionContext.DryRun = $false


if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {    
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = "EnableAccount" # Optionally specify a different action for this audit log
            Message = "The account reference could not be found"
            IsError = $true
        }
    )                
    throw "The account reference could not be found"
}

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
        Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($actionContext.References.Account)"
        Headers     = $headers
        ContentType = 'application/json'
    }
    $responseUser = Invoke-RestMethod @splatParams -Verbose:$false
}
catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "EnableAccount" # Optionally specify a different action for this audit log
                Message = "YsisV2 account for: [$($p.DisplayName)] not found. Possibly deleted"
                IsError = $true
            })
        
    }
    throw
}

if ($actionContext.DryRun -eq $true) {
    $outputContext.Success = $true
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = "EnableAccount" # Optionally specify a different action for this audit log
            Message = "Account [$($p.DisplayName)] with reference  $($actionContext.References.Account) will be enabled"
            IsError = $false
        })
}

if (-Not($actionContext.DryRun -eq $true)) {
    # Write enable logic here    
    try {
        Write-Verbose "Enabling YsisV2 account with accountReference: [$($actionContext.References.Account)]"
        $responseUser.active = $true
        $splatParams = @{
            Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($actionContext.References.Account)"
            Headers     = $headers
            Method      = 'PUT'
            Body        = $responseUser | ConvertTo-Json
            ContentType = 'application/scim+json'
        }
        $null = Invoke-RestMethod @splatParams -Verbose:$false

        $outputContext.Success = $true
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "EnableAccount" # Optionally specify a different action for this audit log
                Message = "Account [$($p.DisplayName)] with reference  $($actionContext.References.Account) enabled"
                IsError = $false
            })
    }
    catch {
        $ex = $PSItem
        if ($($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
            $errorObj = Resolve-YsisV2Error -ErrorObject $ex
            $auditMessage = "Could not enable YsisV2 account. Error: $($errorObj.FriendlyMessage)"
            Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        }
        else {
            $auditMessage = "Could not enable YsisV2 account. Error: $($ex.Exception.Message)"
            Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        }
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "EnableAccount" # Optionally specify a different action for this audit log
                Message = $auditMessage
                IsError = $true
            })
        
    }
}

#Retrieve account information for notifications
#$outputContext.PreviousData.ExternalId = $personContext.References.Account
#$outputContext.Data.UserName    = $actionContext.Data.UserName
#$outputContext.Data.ExternalId  = $personContext.References.Account

