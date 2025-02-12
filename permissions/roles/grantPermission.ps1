###################################################################
# HelloID-Conn-Prov-Target-Ysis-Permissions-Roles-GrantPermission
# PowerShell V2
###################################################################

# Initialize default values
$config = $actionContext.Configuration

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($actionContext.Configuration.isDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
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
#endregion

# Begin
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

    $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
    $headers.Add('Authorization', "Bearer $($responseAccessToken.access_token)")
    $headers.Add('Accept', 'application/json; charset=utf-8')
    $headers.Add('Content-Type', 'application/json')

    Write-Information "Verifying if a Ysis account for [$($personContext.Person.DisplayName)] exists"
    try {
        $splatParams = @{
            Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($actionContext.References.Account)"
            Headers     = $headers
            ContentType = 'application/scim+json;charset=UTF-8'
        }
        $responseUser = Invoke-RestMethod @splatParams -Verbose:$false
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "GrantPermission"
                    Message = "Unable to assign permission [$($actionContext.References.Permission.DisplayName)]. Ysis account for [$($person.DisplayName)] not found. Account is possibly deleted"
                    IsError = $true
                })
            throw "AccountNotFound"
        }
        throw $_
    }
    
    # Process
    Write-Verbose "Pre: all assigned roles ($($responseUser.roles.count)): $($responseUser.roles.displayName -join ", ")"
    Write-Information "Granting Ysis entitlement: [$($actionContext.References.Permission.DisplayName)]"
    if ($responseUser.roles.count -eq 0 -or $actionContext.References.Permission.Reference -notin $responseUser.roles.value) {
        $responseUser.roles += ([PSCustomObject]@{
                value       = $actionContext.References.Permission.Reference
                displayName = $actionContext.References.Permission.DisplayName
            })

        $splatParams = @{
            Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($actionContext.References.Account)"
            Headers     = $headers
            Method      = 'PUT'
            Body        = ($responseUser | ConvertTo-Json -Depth 10)
            ContentType = 'application/scim+json;charset=UTF-8'
        }

        if ($actionContext.DryRun -eq $true) {
            Write-Warning "[DryRun] Will send: $($splatParams.Body)"
        }
        else {
            $null = Invoke-RestMethod @splatParams -Verbose:$false
        }

        Write-Verbose "Post: all assigned roles ($($responseUser.roles.count)): $($responseUser.roles.displayName -join ", ")"
    }
    else {
        Write-Warning "Permission [($($actionContext.References.Permission.DisplayName))] was already assigned in Ysis"
    }

    $outputContext.Success = $true
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = "Grant permission [$($actionContext.References.Permission.DisplayName)] to account with Ysis Initials [$($responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials)] was successful"
            IsError = $false
        })
}
catch {
    $ex = $PSItem
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Warning $_
    }
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-YsisError -ErrorObject $ex
        $auditMessage = "Could not grant Ysis permission [$($actionContext.References.Permission.DisplayName)]. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Could not grant Ysis permission [$($actionContext.References.Permission.DisplayName)]. Error: $($_.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}