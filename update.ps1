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
$aRef = $AccountReference | ConvertFrom-Json

# Additional mapping is needed based on the function of the primary contract
# Example code:
# $mappingTableGrouped = (Get-Content C:\temp\staticMappingTable) | Group-Object -Property Id -AsHashTable -AsString
# $discipline = $mappingTableGrouped[$p.PrimaryContract.Title.ExternalId].Discipline
$discipline = 'Medisch' # Additional Mapping is needed

$account = [PSCustomObject]@{
    id       = $aRef.id  # $p.ExternalId
    userType = $discipline
}


try {
    if ($dryRun) {
        $auditMessage = "Ysis account with discipline [$($account.userType)] will be updated for: $($p.DisplayName)"
    }
    if (-not ($dryRun -eq $true)) {
        if ($aRef.Discipline -ne $account.userType ) {
            Write-Verbose "The accounts discipline is changed from [$($aref.Discipline)] to [$discipline]."
            Write-Verbose 'Will sent a mail to Eric. That the account must be corrected manually.'
            Write-Verbose 'Updating the account reference in HelloID with the new discipline'

            $mailBody = "
            <p>Dear,
            </p>
            <p>The discipline of person [$($p.DisplayName)] is changed from [$($aref.Discipline)] to [$discipline]. HelloId will <b>Not</b> update the account<Br>
            </p>
            <p>Please take action and update manually the account for [$($p.DisplayName)] with the new discipline.
            </p>
            <p>Kind regards,<br>
            </p>
            <p>HelloID<br>
            </p>
            "
            $Subject = "Ysis: Person $($account.id) needs new discipline [$discipline]"

            $SendMailParameters = @{
                From       = 'noreply@HelloID.com'
                To         = $config.To
                Subject    = $Subject
                SmtpServer = $config.SmtpServerAddress
                UseSsl     = $false
                BodyAsHtml = $true
                Body       = $mailBody
            }
            Send-MailMessage @SendMailParameters -ErrorAction Stop
            $auditMessage = "Discipline must be updated to [$discipline]. Mail is sent to the Ysis administrator"
        } else {
            $auditMessage = "No changes where found in account, with iam-id  $($account.id)"
            Write-Verbose  $auditMessage
        }
    }
    $auditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $False
        })
    $accountRef = @{
        Discipline = $account.userType  # Based on HelloID Mapping. The acctual Discipline cannot be retreived from the webservices
        Id         = $account.Id
    }
    $success = $true
} catch {
    $errorMessage = "Could not update account, Error: $($_.Exception.Message)"
    Write-Verbose $errorMessage
    $auditLogs.Add([PSCustomObject]@{
            Message = $errorMessage
            IsError = $true
        })
}

# Build up result
$result = [PSCustomObject]@{
    accountReference = $accountRef
    account          = $account
    Success          = $success
    AuditLogs        = $auditLogs
}

Write-Output $result | ConvertTo-Json -Depth 10