#####################################################
# HelloID-Conn-Prov-Target-Ysis
#
# Version: 1.0.0
#####################################################
$VerbosePreference = 'Continue'

# Initialize default value's
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$success = $false
$auditLogs = New-Object Collections.Generic.List[PSCustomObject]


# Additional mapping is needed based on the function of the primary contract
# Example code:
# $mappingTableGrouped = (Get-Content C:\temp\staticMappingTable) | Group-Object -Property Id -AsHashTable -AsString
# $discipline = $mappingTableGrouped[$p.PrimaryContract.Title.ExternalId].Discipline
$discipline = 'Medisch' # Additional Mapping is needed

$account = [PSCustomObject]@{
    id           = $p.ExternalId
    userName     = $p.Contact.Business.Email #  UPN or emailAddress
    active       = $true  #Creates account in enabled state
    userType     = $discipline
    title        = $p.PrimaryContract.Title.name
    name         = [PSCustomObject]@{
        formatted       = $p.DisplayName
        givenName       = $p.Name.GivenName
        familyName      = $p.Name.FamilyName
        middleName      = $p.Name.FamilyNamePrefix
        honorificPrefix = ''
        honorificSuffix = ''
    }
    emails       = @(
        [PSCustomObject]@{
            value   = $p.Contact.Business.Email
            type    = 'work'
            primary = $true
        }
    )
    phoneNumbers = @(
        [PSCustomObject]@{
            value = $p.Contact.Business.Phone.Fixed
            type  = 'work'
        }
    )
    'urn:ietf:params:scim:schemas:extension:ysis:1.0:User' = [PSCustomObject]@{
        function   = $p.PrimaryContract.Title.Name
        profession = [PSCustomObject]@{
            code        = ''
            meaning     = ''
            explanation = ''  # need to be on of COD878-DBCO, see https://www.vektis.nl/standaardisatie/codelijsten/COD878-DBCO
        }
    }
}

#region Functions
function Get-GenericScimOAuthToken {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $ClientID,

        [Parameter(Mandatory)]
        [string]
        $ClientSecret,

        [Parameter(Mandatory)]
        [string]
        $AuthenticationUrl
    )
    try {
        Write-Verbose "Invoking command '$($MyInvocation.MyCommand)'"
        $body = @{
            client_id     = $ClientID
            client_secret = $ClientSecret
            grant_type    = 'client_credentials'
        }

        $splatRestMethodParameters = @{
            Uri    = "$AuthenticationUrl"
            Method = 'POST'
            Body   = $body
        }
        Invoke-RestMethod @splatRestMethodParameters
        Write-Verbose 'retrieved accessToken'
    } catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

function Invoke-YsisRestMethod {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [System.Collections.Generic.Dictionary[[String], [String]]]
        $Headers,

        [parameter(Mandatory)]
        [PSCustomObject]
        $AccountBody,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Method

    )
    try {
        $splatParams = @{
            Uri     = "$($config.BaseUrl)/scim/v2/Users"
            Headers = $Headers
            Body    = ($AccountBody | ConvertTo-Json -Depth 10)
            Method  = $Method
        }
        if ($Method -eq 'Put') {
            $splatParams['Uri'] = "$($config.BaseUrl)/scim/v2/Users/$($AccountBody.id)"
        }

        $returnValue = Invoke-RestMethod @splatParams

        Write-Output $returnValue
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Resolve-HTTPError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $HttpErrorObj = [PSCustomObject]@{
            FullyQualifiedErrorId = $ErrorObject.FullyQualifiedErrorId
            MyCommand             = $ErrorObject.InvocationInfo.MyCommand
            RequestUri            = $ErrorObject.TargetObject.RequestUri
            ScriptStackTrace      = $ErrorObject.ScriptStackTrace
            ErrorMessage          = ''
        }
        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            $HttpErrorObj.ErrorMessage = $ErrorObject.ErrorDetails.Message
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            $stream = $ErrorObject.Exception.Response.GetResponseStream()
            $stream.Position = 0
            $streamReader = New-Object System.IO.StreamReader $Stream
            $errorResponse = $StreamReader.ReadToEnd()
            $HttpErrorObj.ErrorMessage = $errorResponse
        }
        Write-Output $HttpErrorObj
    }
}
function New-AuthorizationHeaders {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[[String], [String]]])]
    param(
        [parameter(Mandatory)]
        [string]
        $AccessToken
    )
    try {
        Write-Verbose 'Adding Authorization headers'
        $headers = New-Object 'System.Collections.Generic.Dictionary[[String], [String]]'
        $headers.Add('Authorization', "Bearer $($AccessToken)")
        $headers.Add('Accept', 'application/json')
        $headers.Add('Content-Type', 'application/json')
        Write-Output $headers
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
#endregion Functions
try {
    $accessToken = Get-GenericScimOAuthToken -ClientID $config.ClientID -ClientSecret $config.ClientSecret -AuthenticationUrl $config.AuthenticationUrl
    $headers = New-AuthorizationHeaders -AccessToken $accessToken.access_token

    if ($dryRun) {
        $auditMessage = "Ysis account with discipline [$($account.userType)] will be created for: $($p.DisplayName)"
    }

    if (-not ($dryRun -eq $true)) {
        try {
            Write-Verbose "Creating account for '$($p.DisplayName)'"
            $Account | Add-Member -NotePropertyMembers @{
                schemas = @(
                    'urn:ietf:params:scim:schemas:core:2.0:User',
                    'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User'
                )
                meta    = @{
                    resourceType = 'User'
                }
            }
            $null = Invoke-YsisRestMethod -Headers $headers -AccountBody $account -Method 'POST'
            $auditMessage = "Created account with username $($account.userName) and iam-id  $($account.id)"
        } catch {
            if ( $_ -match 'User iam-id moet uniek zijn') {
                $accountExists = $true
            } else {
                Write-Verbose $_
                throw $_
            }
        }

        # Corrolated, Perform update on existing account # Corrolated
        if ($accountExists) {
            Write-Verbose "Account with iam-id  $($account.id) found"
            Write-Verbose "Updating corrolated account on IAM_ID [$($account.id)]"
            $null = Invoke-YsisRestMethod -Headers $headers -AccountBody $account -Method 'PUT'
            $auditMessage = "Corrolated account with iam-id  $($account.id)"
        }
    }

    $accountRef = @{
        Discipline = $account.userType  # Based on HelloID Mapping. The acctual Discipline cannot be retreived from the webservices
        Id         = $account.Id
    }

    $auditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $False
        })
    $success = $true
} catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-HTTPError -Error $ex
        $errorMessage = "Could not create account, Error: $($errorObj.ErrorMessage)"
    } else {
        $errorMessage = "Could not create account, Error: $($ex.Exception.Message)"
    }
    Write-Verbose $errorMessage
    $auditLogs.Add([PSCustomObject]@{
            Message = $errorMessage
            IsError = $true
        })
}

# Build up result
$result = [PSCustomObject]@{
    accountReference = $accountRef
    account          = $account | Select-Object -ExcludeProperty schemas, meta
    Success          = $success
    AuditLogs        = $auditLogs
}

Write-Output $result | ConvertTo-Json -Depth 10
