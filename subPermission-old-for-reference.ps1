######################################################
# HelloID-Conn-Prov-Target-YsisV2-SubPermissions
# PowerShell V2
######################################################

# Initialize default values
$config = $actionContext.Configuration
$outputContext.success = $false

$updateAccount = $false

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = "Continue" }
    $false { $VerbosePreference = "SilentlyContinue" }
}

# Debug:
# $actionContext.CurrentPermissions = '[ { "DisplayName": "USER_MANAGEMENT", "Reference": { "Id": "USER_MANAGEMENT" } },{ "DisplayName": "FINANCIAL", "Reference": { "Id": "FINANCIAL" } }, { "DisplayName": "FINANCIAL_EXPORT_PORTAL", "Reference": { "Id": "FINANCIAL_EXPORT_PORTAL" } }, { "DisplayName": "YSIS_DBC", "Reference": { "Id": "YSIS_DBC" } } ]' | ConvertFrom-Json
# $actionContext.CurrentPermissions = '[{ "DisplayName": "DUMMY", "Reference": { "Id": "DUMMY" } },{ "DisplayName": "FINANCIAL", "Reference": { "Id": "FINANCIAL" } }, { "DisplayName": "FINANCIAL_EXPORT_PORTAL", "Reference": { "Id": "FINANCIAL_EXPORT_PORTAL" } }, { "DisplayName": "YSIS_DBC", "Reference": { "Id": "YSIS_DBC" } } ]' | ConvertFrom-Json

# Determine all the sub-permissions that needs to be Granted/Updated/Revoked
$currentPermissions = @{ }
foreach ($permission in $actionContext.CurrentPermissions) {
    $currentPermissions[$permission.Reference.Id] = $permission.DisplayName
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

try {
    $account = $actionContext.Data;
    $person = $personContext.Person;

    $ModuleSearchField = "JobTitleId";
    $mapping = Import-Csv "$($config.MappingFile)" -Delimiter ";"
    

    # Remove ID field because only used for export data
    if ($account.PSObject.Properties.Name -Contains 'id') {
        $account.PSObject.Properties.Remove('id')
    }

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
    $headers.Add('Accept', 'application/json; charset=utf-8')
    $headers.Add('Content-Type', 'application/json')

    Write-Verbose "Verifying if YsisV2 account for [$($person.DisplayName)] exists"
    try {
        $splatParams = @{
            Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($actionContext.References.Account)"
            Headers     = $headers
            ContentType = 'application/scim+json;charset=UTF-8'
        }
        $currentAccount = Invoke-RestMethod @splatParams -Verbose:$false

        if ($null -eq $currentAccount) {
            Throw " Could not Update Ysis account - cannot find User"
        }

    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "UpdateAccount"
                    Message = "YsisV2 account for: [$($person.DisplayName)] not found. Possibly deleted"
                    IsError = $true
                })
            throw "Possibly deleted"
        }
        throw $_
    }

    #current modules

    $NewUserModules = [System.Collections.Generic.List[object]]::new()

    $currentUserModules = [System.Collections.Generic.List[object]]::new()
    $currentUserModules.AddRange($currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules) 

    $NewUserModules.AddRange($currentUserModules)

    write-verbose "currentUser modules: $($CurrentUserModules | convertto-json)"

    $desiredPermissions = @{ }

    #adding defailt Module
    $desiredPermissions[$config.defaultModule] = $config.defaultModule


    if (-Not($actionContext.Operation -eq "revoke")) {
        foreach ($contract in $personContext.Person.Contracts) {
            if ($contract.Context.InConditions -or $actionContext.DryRun -eq $true) {

                $ModuleSearchValue = $contract.Title.Code  

                Write-Verbose "searching for value $($ModuleSearchValue) in field : $($ModuleSearchField)"
                $mappedObject = $mapping | Where-Object { $_.$ModuleSearchField -eq $ModuleSearchValue }

                $modules = $mappedObject.module -split (",")
                Write-Verbose "mapped modules: $($modules -join("|"))"

                foreach ($mappedModule in $modules) {           
                    if (-NOT [string]::isnullorempty($mappedModule)) {
                        $desiredPermissions[$mappedModule] = $mappedModule
                    }
                }

            }
        }
    }

    # Compare desired with current permissions and grant permissions
    foreach ($permission in $desiredPermissions.GetEnumerator()) {

        if (-NOT ($currentUserModules -contains $permission.Name)) {
            $null = $NewUserModules.add($permission.Name)
            $updateAccount = $true

            if (($actionContext.DryRun -eq $true)) {
                write-warning "[DRYRUN]: will grant [$($permission.Name)]"
            }

            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "GrantPermission"
                    Message = "added YSIS-module $($permission.Value)"
                    IsError = $false
                })

        }
        else {
            if (($actionContext.DryRun -eq $true)) {
                write-warning "[DRYRUN]: existing permission [$($permission.Name)]"
            }
        }

        $outputContext.SubPermissions.Add([PSCustomObject]@{
                DisplayName = $permission.Value
                Reference   = [PSCustomObject]@{
                    Id = $permission.Name
                }
            })
        
    }

    # Compare current with desired permissions and revoke permissions
    foreach ($permission in $currentPermissions.GetEnumerator()) {
        if (-Not $desiredPermissions.ContainsKey($permission.Name) -AND $permission.Name -ne "No Groups Defined") {

        
            if (($currentUserModules -contains $permission.Name)) {
                $null = $NewUserModules.remove($permission.Name)
                $updateAccount = $true

                if (($actionContext.DryRun -eq $true)) {
                    write-warning "[DRYRUN]: will revoke [$($permission.Name)]"
                }

                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Action  = "RevokePermission"
                        Message = "removed YSIS-module $($permission.Value)"
                        IsError = $false
                    })

            }
            else {
                if (($actionContext.DryRun -eq $true)) {
                    write-warning "[DRYRUN]: non-existing permission [$($permission.Name)]"
                }
            }
        }
    }

    write-verbose "new current modules: $($NewUserModules | convertto-json)"
    if ($updateAccount) {
        $currentAccount.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules = $NewUserModules

        $splatUpdateUserParams = @{
            Uri         = "$($config.BaseUrl)/gm/api/um/scim/v2/users/$($actionContext.References.Account)"
            Headers     = $headers
            Method      = 'PUT'
            Body        = $currentAccount | ConvertTo-Json
            ContentType = 'application/scim+json;charset=UTF-8'
        }

        if (-NOT ($actionContext.DryRun -eq $true)) {
            $null = Invoke-RestMethod @splatUpdateUserParams -Verbose:$false   
        }
        else {
            write-warning "[DRYRUN]: will update $($actionContext.References.Account) with new modules: $($NewUserModules | convertto-json)"
        }

        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "UpdatePermission"
                Message = "Updated Modules for user [$($actionContext.References.Account)]"
                IsError = $false
            })

    }
    else {
        if (($actionContext.DryRun -eq $true)) {
            write-warning "[DRYRUN]: modules not changed"

            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "UpdatePermission"
                    Message = "skip updating Modules for user - no changes"
                    IsError = $false
                })
        }
        
    }
}
catch {
    $ex = $PSItem
    if (-Not($ex.Exception.Message -eq 'Possibly deleted')) {
        if ($($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
            $errorObj = Resolve-YsisV2Error -ErrorObject $ex
            $auditMessage = "Could not update YsisV2 modules. Error: $($errorObj.FriendlyMessage)"
            Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        }
        else {
            $auditMessage = "Could not update YsisV2 modules. Error: $($ex.Exception.Message)"
            Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        }
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "UpdatePermission"
                Message = $auditMessage
                IsError = $true
            })
    }
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-NOT($outputContext.AuditLogs.IsError -contains $true)) {
        $outputContext.Success = $true
    }

    # Handle case of empty defined dynamic permissions.  Without this the entitlement will error.
    if ($actioncontext.Operation -match "update|grant" -AND $outputContext.SubPermissions.count -eq 0) {
        $outputContext.SubPermissions.Add([PSCustomObject]@{
                DisplayName = "No Groups Defined"
                Reference   = [PSCustomObject]@{
                    Id = "No Groups Defined"
                }
            })
    }
}