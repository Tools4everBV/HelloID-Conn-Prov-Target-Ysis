function generateLastName() {
 
 
    let middleName = Person.Name.FamilyNamePrefix;
    let lastName = Person.Name.FamilyName;
    let middleNamePartner = Person.Name.FamilyNamePartnerPrefix;
    let lastNamePartner = Person.Name.FamilyNamePartner;
 
    let nameFormatted = "";
 
    switch(Person.Name.Convention) {
    case "B":        
        nameFormatted = lastName;
        break;
    case "P":
        nameFormatted = lastNamePartner;
        break;
    case "BP":        
        nameFormatted = lastName + ' - ';
        if (typeof middleNamePartner !== 'undefined' && middleNamePartner) { nameFormatted = nameFormatted + middleNamePartner + ' ' }
        nameFormatted = nameFormatted + lastNamePartner;
        break;
    case "PB":        
        nameFormatted = lastNamePartner + ' - ';
        if (typeof middleName !== 'undefined' && middleName) { nameFormatted = nameFormatted + middleName + ' ' }
        nameFormatted = nameFormatted + lastName;
        break;
    default:        
        nameFormatted = lastName;
        break;
    }
    nameFormatted = nameFormatted.trim();
 
return nameFormatted;
}
generateLastName()