########################################
# HelloID-Conn-Prov-Target-YsisV2-Permissions-Roles
# PowerShell V2
########################################

# Initialize default values
$config = $actionContext.Configuration
$outputContext.success = $false

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($actionContext.Configuration.isDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
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

function Get-AccountRoles {
    [cmdletbinding()]
    Param ()    
    try{
        Write-Verbose 'Adding Authorization headers'
        $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
        $headers.Add('Authorization', "Bearer $($responseAccessToken.access_token)")
        $headers.Add('Accept', 'application/json; charset=utf-8')
        $headers.Add('Content-Type', 'application/json')
        
        # Get Role
        $splatRoleParams = @{
            Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/roles"
            Method      = 'GET'
            Headers     = $headers
            ContentType = 'application/json'
        }
        $roles = Invoke-RestMethod @splatRoleParams -Verbose:$true

    }catch{
        Write-Warning "$($_)"
        throw "Failed retrieving roles - $($_)"
    }

    return $roles
}
#endregion functions

try {    
    # Requesting authorization token
    try {
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
    }
    catch {
        write-error "$($_)"
        $ex = $PSItem
        if ($($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
            $errorObj = Resolve-YsisV2Error -ErrorObject $ex
            $auditMessage = "Could not retrieve Ysis Token. Error: $($errorObj.FriendlyMessage)"
            Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        }
        else {
            $auditMessage = "Could not retrieve Ysis Token. Error: $($ex.Exception.Message)"
            Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        }
        throw "$auditMessage"
    }

    $roles = Get-AccountRoles | Sort-Object -Property displayName

    foreach ($r in $roles ) {
        $outputContext.Permissions.Add(
            @{
                DisplayName    = "Role: $($r.displayName)"
                Identification = @{
                    Id = $r.value
                }
            }
        )
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

}
