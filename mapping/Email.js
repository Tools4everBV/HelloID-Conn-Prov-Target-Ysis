//YSIS only accepts one e-mailadress
function GetMailAddresses(){   

    let mail = ""    
    
    if(typeof Person.Accounts.MicrosoftActiveDirectory.mail !== 'undefined' && Person.Accounts.MicrosoftActiveDirectory.mail) {        
        mail = Person.Accounts.MicrosoftActiveDirectory.mail
    }   

    return mail
}
GetMailAddresses()