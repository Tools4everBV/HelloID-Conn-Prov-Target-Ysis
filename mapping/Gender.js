function getValue() {
    switch (Person.Details.Gender) {
        case "V": return "FEMALE"
        case "M": return "MALE"
        default: return"UNKNOWN"
    }    
}
getValue();