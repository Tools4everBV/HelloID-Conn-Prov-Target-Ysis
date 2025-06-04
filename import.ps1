#####################################################
# HelloID-Conn-Prov-Target-Ysis-Import
# PowerShell V2
#####################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

try {
    Write-Information 'Starting target account import'


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
	$headers = [System.Collections.Generic.Dictionary[string, string]]::new()
	$headers.Add('Authorization', "Bearer $($responseAccessToken.access_token)")
	$headers.Add('Accept', 'application/json; charset=utf-8')
	$headers.Add('Content-Type', 'application/json')

	$splatParams = @{
		Uri         = "$($actionContext.Configuration.BaseUrl)/gm/api/um/scim/v2/users?filter=urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:employeeNumber%20pr%20"
		Method      = 'GET'
		Headers     = $headers
		ContentType = 'application/json'
	}
	$existingAccounts = Invoke-RestMethod @splatParams -Verbose:$false

    $existingAccounts  | Add-Member -MemberType NoteProperty -Name 'AgbCode' -Value $null
    $existingAccounts  | Add-Member -MemberType NoteProperty -Name 'BigNumber' -Value $null
    $existingAccounts  | Add-Member -MemberType NoteProperty -Name 'Discipline' -Value $null
    $existingAccounts  | Add-Member -MemberType NoteProperty -Name 'Email' -Value $null
    $existingAccounts  | Add-Member -MemberType NoteProperty -Name 'EmployeeNumber' -Value $null
    $existingAccounts  | Add-Member -MemberType NoteProperty -Name 'GivenName' -Value $null
    $existingAccounts  | Add-Member -MemberType NoteProperty -Name 'Infix' -Value $null
    $existingAccounts  | Add-Member -MemberType NoteProperty -Name 'Initials' -Value $null
    $existingAccounts  | Add-Member -MemberType NoteProperty -Name 'MobilePhone' -Value $null
    $existingAccounts  | Add-Member -MemberType NoteProperty -Name 'Position' -Value $null
    $existingAccounts  | Add-Member -MemberType NoteProperty -Name 'WorkPhone' -Value $null
    $existingAccounts  | Add-Member -MemberType NoteProperty -Name 'YsisInitials' -Value $null
    $existingAccounts  | Add-Member -MemberType NoteProperty -Name 'FamilyName' -Value $null


    # Map the imported data to the account field mappings
    foreach ($account in $existingAccounts) {
        $enabled = $account.active
        
        if ([string]::IsNullOrEmpty($account.name.Infix)) {
            $displayName = $account.name.givenName + ' ' + $account.name.familyName
        }
        else {
            $displayName = $account.name.givenName + ' ' + $account.name.Infix + ' ' + $account.name.familyName 
        }

        $account.EmployeeNumber = $account.'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User'.EmployeeNumber
        $account.AgbCode = $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.agbCode
        $account.BigNumber = $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.bigNumber
        $account.Discipline = $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.discipline
        $account.Email = $account.emails[0].value
        $account.GivenName = $account.name.givenname
        $account.Infix = $account.name.infix
        $account.FamilyName = $account.name.familyname
        $account.Initials = $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.initials
        $account.MobilePhone = ($account.phoneNumbers | Where-Object {$_.type -eq 'mobile'}).value
        $account.Position = $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.position
        $account.WorkPhone = ($account.phoneNumbers | Where-Object {$_.type -eq 'work'}).value
        $account.YsisInitials = $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.ysisInitials


        # Return the result
        Write-Output @{
            AccountReference = $account.id
            DisplayName      = $displayName
            UserName         = $account.userName
            Enabled          = $enabled
            Data             = $account
        }
    }
    Write-Information 'Target account import completed'
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {

        if (-Not [string]::IsNullOrEmpty($ex.ErrorDetails.Message)) {
            Write-Information "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.ErrorDetails.Message)"
            Write-Error "Could not import account entitlements. Error: $($ex.ErrorDetails.Message)"
        }
        else {
            Write-Information "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
            Write-Error "Could not import account entitlements. Error: $($ex.Exception.Message)"
        }
    }
    else {
        Write-Information "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import account entitlements. Error: $($ex.Exception.Message)"
    }
}