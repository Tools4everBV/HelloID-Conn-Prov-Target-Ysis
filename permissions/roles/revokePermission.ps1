#################################################
# HelloID-Conn-Prov-Target-Ysis-Revoke
# PowerShell V2
#################################################

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
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            # Make sure to inspect the error result object and add only the error message as a FriendlyMessage.
            # $httpErrorObj.FriendlyMessage = $errorDetailsObject.message
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails # Temporarily assignment
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
                    Message = "Unable to assign permission [$($actionContext.References.Permission.displayName)]. Ysis account for [$($person.DisplayName)] not found. Possibly deleted" # Todo error message
                    IsError = $true
                })
            throw "Possibly deleted"
        }
        throw $_
    }

    if ($actionContext.DryRun -eq $true) {
        Write-Information "[DryRun] Revoke Ysis entitlement: [$($actionContext.References.Permission.DisplayName)], will be executed during enforcement"
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Message = "[DryRun] Revoke permission [$($actionContext.References.Permission.DisplayName)] was successful"
                IsError = $false
            })
        $outputContext.Success = $true
    }
    else {
        Write-Information "Revoking Ysis entitlement: [$($actionContext.References.Permission.DisplayName)]"

        if (($responseUser.roles.value.Contains($actionContext.References.Permission.Reference))) {
            if ($responseUser.roles.count -gt 0 -and $actionContext.References.Permission.Reference -in $responseUser.roles.value) {
                $responseUser.roles = $responseUser.roles | Where-Object { $_.value -notcontains $actionContext.References.Permission.Reference }

                $splatParams = @{
                    Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($actionContext.References.Account)"
                    Headers     = $headers
                    Method      = 'PUT'
                    Body        = $responseUser | ConvertTo-Json
                    ContentType = 'application/scim+json;charset=UTF-8'
                }
                $null = Invoke-RestMethod @splatParams -Verbose:$false
            }
            else {
                write-information "Permission is already revoked"
            }

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Revoke permission [$($actionContext.References.Permission.DisplayName)] was successful"
                    IsError = $false
                })
        }
    }
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-YsisError -ErrorObject $ex
        $auditMessage = "Could not revoke Ysis permission. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Could not revoke Ysis permission. Error: $($_.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
