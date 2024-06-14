#################################################
# HelloID-Conn-Prov-Target-Ysis-Delete
# PowerShell V2
#################################################

# Initialize default values
$config = $actionContext.Configuration
$person = $personContext.Person
$outputContext.Success = $false

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
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
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

    Write-Verbose "Verifying if Ysis account for [$($person.DisplayName)] exists"
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
                    Action  = "DeleteAccount"
                    Message = "Ysis account for [$($person.DisplayName)] could not be found by account reference [$($actionContext.References.Account)] and is possibly already deleted. Skipping action"
                    IsError = $false
                })
            $responseUser = $null
        }
        else {
            throw $_
        }
    }

    if ($responseUser) {
        if ($actionContext.DryRun -eq $true) {
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "DeleteAccount"
                    Message = "[DryRun] Delete Ysis account for [$($person.DisplayName)] with reference [$($actionContext.References.Account)] will be executed during enforcement"
                    IsError = $false
                })
        }

        if (-Not($actionContext.DryRun -eq $true)) {
            if ($config.UpdateUsernameOnDelete -eq $true) {
                # Optional update Username before "archive"
                Write-Verbose "Updating Ysis account with accountReference: [$($actionContext.References.Account)]"
                $responseUser.userName = $responseUser.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials
                $splatParams = @{
                    Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($actionContext.References.Account)"
                    Headers     = $headers
                    Method      = 'PUT'
                    Body        = $responseUser | ConvertTo-Json
                    ContentType = 'application/scim+json'
                }
                $null = Invoke-RestMethod @splatParams -Verbose:$false

                Write-Verbose "Username of account [$($person.DisplayName)] with reference [$($actionContext.References.Account)] updated"
            }
            Write-Verbose "Deleting Ysis account with userName accountReference [$($actionContext.References.Account)]"
            $splatParams = @{
                Uri     = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($actionContext.References.Account)"
                Headers = $headers
                Method  = 'DELETE'
            }
            $null = Invoke-RestMethod @splatParams -Verbose:$false

            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "DeleteAccount"
                    Message = "Delete account [$($person.DisplayName)] with reference  [$($actionContext.References.Account)] was successful"
                    IsError = $false
                })
        }
    }
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-YsisError -ErrorObject $ex
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "DeleteAccount"
                Message = "Could not delete Ysis account. Error: $($errorObj.FriendlyMessage)"
                IsError = $true
            })
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "DeleteAccount"
                Message = "Could not delete Ysis account. Error: $($ex.Exception.Message)"
                IsError = $true
            })
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-NOT($outputContext.AuditLogs.IsError -contains $true)) {
        $outputContext.Success = $true
    }
}