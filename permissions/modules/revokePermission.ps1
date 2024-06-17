###################################################################
# HelloID-Conn-Prov-Target-Ysis-Permissions-Modules-RevokePermission
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
            $httpErrorObj.ErrorDetails = "Message: $($errorDetailsObject.detail), type: $($errorDetailsObject.scimType)"
            $httpErrorObj.FriendlyMessage = "$($errorDetailsObject.detail), type: $($errorDetailsObject.scimType)"
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
                    Message = "Unable to revoke permission [$($actionContext.References.Permission.displayName)]. Ysis account for [$($person.DisplayName)] not found. Possibly deleted"
                    IsError = $false
                })
            throw "AccountNotFound"
        }
        throw $_
    }

    Write-Verbose "Pre: all assigned modules ($($responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules.count)): $($responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules -join ", ")"
    Write-Information "Revoking Ysis entitlement: [$($actionContext.References.Permission.DisplayName)]"

    if ($responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules.count -gt 0 -and $actionContext.References.Permission.Reference -in $responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules) {
        [Array]$responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules = $responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules | Where-Object { $_ -notcontains $actionContext.References.Permission.Reference }

        $splatParams = @{
            Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($actionContext.References.Account)"
            Headers     = $headers
            Method      = 'PUT'
            Body        = $responseUser | ConvertTo-Json
            ContentType = 'application/scim+json;charset=UTF-8'
        }
        if ($actionContext.DryRun -eq $true) {
            Write-Warning "[DryRun] Will send: $($splatParams.Body)"
        }
        else {
            $null = Invoke-RestMethod @splatParams -Verbose:$false
        }

        Write-Verbose "Post: all assigned modules ($($responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules.count)): $($responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules -join ", ")"
    }
    else {
        Write-Warning "Permission [$($actionContext.References.Permission.DisplayName)] is already revoked"
    }

    $outputContext.Success = $true
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = "Revoke permission [$($actionContext.References.Permission.DisplayName)] was successful"
            IsError = $false
        })
}
catch {
    $ex = $PSItem
    if (-not($ex.Exception.Message -eq 'AccountNotFound')) {
        if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
            $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
            $errorObj = Resolve-YsisError -ErrorObject $ex
            $auditMessage = "Could not revoke Ysis permission [$($actionContext.References.Permission.DisplayName)]. Error: $($errorObj.FriendlyMessage)"
            Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        }
        else {
            $auditMessage = "Could not revoke Ysis permission [$($actionContext.References.Permission.DisplayName)]. Error: $($_.Exception.Message)"
            Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        }
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Message = $auditMessage
                IsError = $true
            })
    }
}