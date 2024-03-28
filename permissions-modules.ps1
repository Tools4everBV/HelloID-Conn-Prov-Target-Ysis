$outputContext.Permissions.Add(
    @{
        DisplayName    = "Module: Behandeldossier?"
        Identification = @{
            Reference = "MOD_YSIS_CORE"
        }
    }
)

$outputContext.Permissions.Add(
    @{
        DisplayName    = "Module: FINANCIAL (voor GRZ, Basis GGZ, ELV en ZPM)"
        Identification = @{
            Reference = "MOD_FINANCIAL"
        }
    }
)

$outputContext.Permissions.Add(
    @{
        DisplayName    = "Module: YSIS_DBC (Financieel voor 1e lijns?....))"
        Identification = @{
            Reference   = "MOD_YSIS_DBC"
            DisplayName = "Module: YSIS_DBC (Financieel voor 1e lijns?....))"
        }
    }
)
$outputContext.Permissions.Add(
    @{
        DisplayName    = "Module: Gebruikersbeheer"
        Identification = @{
            Reference   = "MOD_USER_MANAGEMENT"
            DisplayName = "Module: Gebruikersbeheer"
        }
    }
)
$outputContext.Permissions.Add(
    @{
        DisplayName    = "Module: Portaal financiële koppeling"
        Identification = @{
            Reference   = "MOD_FINANCIAL_EXPORT_PORTAL"
            DisplayName = "Module: Portaal financiële koppeling"
        }
    }
)