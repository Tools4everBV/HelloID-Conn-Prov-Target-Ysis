function generateMiddleName() {
 
 
    let middleName = Person.Name.FamilyNamePrefix;
    let middleNamePartner = Person.Name.FamilyNamePartnerPrefix;
    
    let nameFormatted = "";
 
    switch(Person.Name.Convention) {
    case "B":
    case "BP":
        if (typeof middleName !== 'undefined' && middleName) { nameFormatted = middleName }
        break;
    case "P":
    case "PB":
        if (typeof middleNamePartner !== 'undefined' && middleNamePartner) { nameFormatted = middleNamePartner  }
        break;    
    default:
        if (typeof middleName !== 'undefined' && middleName) { nameFormatted = middleName  }
        break;
    }
    nameFormatted = nameFormatted.trim();
 
return nameFormatted;
}
generateMiddleName()