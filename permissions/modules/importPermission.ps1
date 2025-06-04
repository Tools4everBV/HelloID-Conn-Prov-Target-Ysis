#####################################################
# HelloID-Conn-Prov-Target-Ysis-Permissions-Module-Import
# PowerShell V2
#####################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

try {
    Write-Information 'Starting target permission import'


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

    # Map the imported data to the account field mappings
    foreach ($account in $existingAccounts) {
        foreach ($module in $account.'urn:ietf:params:scim:schemas:extension:ysis:2.0:User'.modules){
            $displayName = $module
            switch($module){
                'YSIS_CORE' { 
                    $displayName = "Module: Behandeldossier"
                    break
                }
                'YSIS_DBC' { 
                    $displayName = "Module: Financieel voor GRZ, Basis GGZ, ELV en ZPM"
                    break
                }
                'FINANCIAL' { 
                    $displayName = "Module: Financieel voor eerstelijns paramedische zorg, huisartsenzorg en GSZP"
                    break
                }
                'FINANCIAL_EXPORT_PORTAL' { 
                    $displayName = "Module: Portaal financiële koppeling"
                    break
                }
                'USER_MANAGEMENT' { 
                    $displayName = "Module: Gebruikersbeheer"
                    break
                }
                'MANAGEMENT' { 
                    $displayName = "Module: Administratieve ondersteuning"
                    break
                }
                'EDC_CARE' { 
                    $displayName = "Module: Zorgdossier"
                    break
                }
            }

            $permission = @{
                PermissionReference = @{
                    Reference = $module
                }       
                DisplayName         = $displayName
                AccountReferences = @($account.id)
            }

            # Return the result
            Write-Output $permission
            
        }
    }
    Write-Information 'Target permission import completed'
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {

        if (-Not [string]::IsNullOrEmpty($ex.ErrorDetails.Message)) {
            Write-Information "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.ErrorDetails.Message)"
            Write-Error "Could not import permission entitlements. Error: $($ex.ErrorDetails.Message)"
        }
        else {
            Write-Information "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
            Write-Error "Could not import permission entitlements. Error: $($ex.Exception.Message)"
        }
    }
    else {
        Write-Information "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import permission entitlements. Error: $($ex.Exception.Message)"
    }
}