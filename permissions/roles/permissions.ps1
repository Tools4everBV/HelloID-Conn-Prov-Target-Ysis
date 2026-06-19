###################################################################
# HelloID-Conn-Prov-Target-Ysis-Permissions-Roles-Permission
# PowerShell V2
###################################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12


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

function Get-AccountRoles {
    [cmdletbinding()]
    Param ()
    try {
        Write-Information 'Adding Authorization headers'
        $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
        $headers.Add('Authorization', "Bearer $($responseAccessToken.access_token)")
        $headers.Add('Accept', 'application/json; charset=utf-8')
        $headers.Add('Content-Type', 'application/json')

        # Get Role
        $splatRoleParams = @{
            Uri         = "$($actionContext.Configuration.BaseUrl)/gm/api/um/scim/v2/roles"
            Method      = 'GET'
            Headers     = $headers
            ContentType = 'application/json'
        }
        $roles = Invoke-RestMethod @splatRoleParams -Verbose:$true

    }
    catch {
        Write-Warning "$($_)"
        throw "Failed retrieving roles - $($_)"
    }

    return $roles
}
#endregion functions

try {
    # Requesting authorization token
    $splatRequestToken = @{
        Uri    = "$($actionContext.Configuration.BaseUrl)/cas/oauth/token"
        Method = 'POST'
        Body   = @{
            client_id     = $($actionContext.Configuration.ClientID)
            client_secret = $($actionContext.Configuration.ClientSecret)
            scope         = 'scim'
            grant_type    = 'client_credentials'
        }
    }

    $responseAccessToken = Invoke-RestMethod @splatRequestToken -Verbose:$false

    $roles = Get-AccountRoles | Sort-Object -Property displayName

    foreach ($r in $roles ) {
        $outputContext.Permissions.Add(
            @{
                DisplayName    = "Role: $($r.displayName)"
                Identification = @{
                    Reference   = $r.value
                }
            }
        )
    }
}
catch {
    $ex = $PSItem
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Warning $_
    }
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-YsisError -ErrorObject $ex
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Write-Warning "Error: $($errorObj.FriendlyMessage)"
    }
    else {
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
}
