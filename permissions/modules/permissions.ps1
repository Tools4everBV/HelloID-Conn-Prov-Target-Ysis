###################################################################
# HelloID-Conn-Prov-Target-Ysis-Permissions-Modules-Permissions
# PowerShell V2
###################################################################

$outputContext.Permissions.Add(
    @{
        DisplayName    = "Module: Behandeldossier"
        Identification = @{
            Reference = "YSIS_CORE"
        }
    }
)

$outputContext.Permissions.Add(
    @{
        DisplayName    = "Module: Financieel voor GRZ, Basis GGZ, ELV en ZPM"
        Identification = @{
            Reference = "YSIS_DBC"
            DisplayName    = "Module: Financieel voor GRZ, Basis GGZ, ELV en ZPM"
        }
    }
)

# # EDC_CARE Is documented in the API documentation, but still in development by Gerimedica (verified 15-05-2024)
# $outputContext.Permissions.Add(
#     @{
#         DisplayName    = "Module: Zorgdossier"
#         Identification = @{
#             Reference = "EDC_CARE"
#         }
#     }
# )

$outputContext.Permissions.Add(
    @{
        DisplayName    = "Module: Financieel voor eerstelijns paramedische zorg, huisartsenzorg en GSZP"
        Identification = @{
            Reference   = "FINANCIAL"
            DisplayName = "Module: Financieel voor eerstelijns paramedische zorg, huisartsenzorg en GSZP"
        }
    }
)

$outputContext.Permissions.Add(
    @{
        DisplayName    = "Module: Portaal financiële koppeling"
        Identification = @{
            Reference   = "FINANCIAL_EXPORT_PORTAL"
            DisplayName = "Module: Portaal financiële koppeling"
        }
    }
)

# # MANAGEMENT Is documented in the API documentation, but still in development by Gerimedica (verified 15-05-2024)
# $outputContext.Permissions.Add(
#     @{
#         DisplayName    = "Module: Administratieve ondersteuning"
#         Identification = @{
#             Reference   = "MANAGEMENT"
#             DisplayName = "Module: Administratieve ondersteuning"
#         }
#     }
# )

$outputContext.Permissions.Add(
    @{
        DisplayName    = "Module: Gebruikersbeheer"
        Identification = @{
            Reference   = "USER_MANAGEMENT"
            DisplayName = "Module: Gebruikersbeheer"
        }
    }
)

# Delete default permission from list and sort op displayname
# $outputContext.Permissions = $outputContext.Permissions | Where-Object {($_.Identification.Reference -ne $actionContext.Configuration.DefaultModule)} | Sort-Object DisplayName
$outputContext.Permissions = $outputContext.Permissions | Sort-Object DisplayName