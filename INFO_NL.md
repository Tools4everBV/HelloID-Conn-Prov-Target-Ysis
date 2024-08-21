De Ysis Target Connect maakt het mogelijk Ysis via de identity & access management (IAM)-oplossing HelloID van Tools4ever aan diverse bronsystemen te koppelen. De integratie versterkt en stroomlijnt onder meer het beheer van toegangsrechten en gebruikersaccounts, waarbij automatisering centraal staat. HelloID baseert zich daarbij altijd op gegevens die het ophaalt uit je bronsystemen. In dit artikel gaan we verder in op de mogelijkheden en voordelen van de Ysis Target connector. 

## Wat is Ysis?

Ysis is software ontwikkeld door Gerimedica. De software ondersteunt de complexe zorg die kwetsbaren nodig hebben. Naar schatting maakt ongeveer de helft van alle behandelaren in de sector gebruik van Ysis; dagelijks loggen zo’n 30.000 zorgprofessionals in op de oplossing. Ysis minimaliseert de tijd dat zorgprofessionals achter een beeldscherm doorbrengen, zodat zij meer tijd overhouden voor het leveren van zorg. De oplossing is afgestemd op de behoeften van zowel artsen, verpleegkundigen, behandelaren en zorgmedewerkers in de ouderen-, wijk- en gehandicaptenzorg. Denk echter ook professionals die de administratie en declaratie van geleverde zorg op zich nemen. 

## Waarom is Ysis koppeling handig?

Ysis speelt dus een belangrijke rol in het leveren van de juiste zorg aan kwetsbaren. Het is dan ook van groot belang dat werknemers, ongeacht of het gaat om vaste krachten, flexwerkers of uitzendkrachten, toegang hebben tot Ysis. Dankzij de koppeling tussen je bronsystemen en Ysis via HelloID heb je hiernaar geen omkijken. De IAM-oplossing detecteert automatisch mutaties in je bronsystemen, ongeacht of het gaat om het aanmaken van een nieuwe gebruiker of bijvoorbeeld een functiewijziging. Op basis hiervan maakt HelloID geautomatiseerd het benodigde account in Ysis aan, of muteert een bestaand account. Let op: het muteren van disciplines is niet mogelijk vanuit Ysis. 

De koppeling bespaart je veel tijd en zorgt voor een uniforme werkwijze. Tijmen Lodders, ICT-medewerker bij Stichting TanteLouise, licht toe: 

**_“In het verleden maakten we met de hand accounts aan en koppelden we rechten. Nu hebben we dat aan rollen gehangen en wordt alles geautomatiseerd door HelloID. Voor de rest hoeven wij er niks meer mee. Ik check alleen nog twee keer per week of het nog goed werkt, maar dat is het enige. Hiervoor waren we hier per account een minuut of 20 mee bezig. Dat is nu gewoon niet meer nodig.“_**

De Ysis connector maakt integraties met veelvoorkomende systemen mogelijk. Denk daarbij aan: 

*	Active Directory/Entra ID
*	AFAS

Meer informatie over de integratie met deze bronsystemen vind je verderop in dit artikel.

## HelloID voor Ysis helpt je met

**Versnelde accountaanmaak:** De koppeling tussen je bronsystemen en Ysis via HelloID zorgt dat je de Ysis-accounts die werknemers nodig hebben sneller aanmaakt. De IAM-oplossing automatiseert dit proces, zodat jij hiernaar geen omkijken hebt. Zo stel je zeker dat nieuwe werknemers op hun eerste werkdag direct aan de slag kunnen. 

**Foutloos accountbeheer:** HelloID koppelt op basis van het afhankelijke account - Active Directory of Entra ID - het e-mailadres van de gebruiker aan het Ysis-account. De IAM-oplossing hanteert hierbij vaste procedures, waardoor je altijd zeker weet dat alle benodigde stappen zijn uitgevoerd en daarnaast de foutgevoeligheid terugdringt. Ook legt HelloID alle activiteiten gerelateerd aan gebruikers of autorisaties vast in een logbestand. Zo kan je altijd aantonen dat je aan de geldende compliance-eisen voldoet. 

**Verbeterde serviceniveaus en beveiliging:** De koppeling tussen je bronsystemen en Ysis verbetert ook je beveiligingsniveau. Zo zorg je dat accounts van voormalig werknemers nooit onbedoeld actief blijven. Belangrijk, want hiermee biedt je eventuele aanvallers onnodige kansen. Tegelijkertijd verbetert de koppeling je serviceniveau. Zo beschikken gebruikers sneller over het benodigde Ysis-account en zijn mutaties hieraan sneller verwerkt. Ook maak je minder vermijdbare fouten, wat de gebruikerstevredenheid verhoogt en waardoor je minder tijd kwijt bent aan het corrigeren van fouten.

## Hoe HelloID integreert met Ysis

Je kunt Ysis als doelsysteem koppelen aan HelloID. De IAM-oplossing maakt hierbij gebruik van de API van Ysis, die is gebaseerd op System for Cross-domain Identity Management (SCIM). Ysis maakt voor het gebruik van deze API gebruik van whitelisting. Dit betekent in de praktijk dat een on-premises HelloID agent nodig is voor het realiseren van deze koppeling. 

Let op: HelloID kan initieel vastleggen bij welke discipline een Ysis-account hoort, maar kan deze discipline niet automatisch bijwerken bij mutaties. HelloID detecteert de wijziging van de discipline in je bronsysteem wel, en kan de functioneel beheerder van Ysis hiervan via e-mail op de hoogte stellen. De functioneel beheerder kan de mutatie vervolgens handmatig verwerken. 

| Wijziging in bronsysteem | 	Procedure in Ysis |
| ------------------------ | ------------------ | 
| **Nieuwe medewerker** |	Treedt een nieuwe medewerker in dienst? HelloID detecteert dit in je bronsystemen, en maakt automatisch het benodigde gebruikersaccount aan in Ysis. Zo kunnen nieuwe medewerkers direct aan de slag. 
| **Gegevens werknemer** |  wijzigen	HelloID merkt wijzigingen van gegevens in je bronsysteem automatisch op, en kan deze verwerken in Ysis. Denk daarbij aan de naam van werknemer, bijvoorbeeld indien hij of zij is getrouwd. Let op: HelloID kan niet geautomatiseerd een discipline bijwerken in Ysis. | 
| **Functie van medewerker verandert** |	Op basis van de informatie uit je bronsystemen kan HelloID een Ysis-account onder meer lid maken van een specifieke module en/of rol in Ysis. Bijvoorbeeld om declaraties te kunnen maken voor onder meer eerstelijns paramedische zorg, de DBC-GRZ en de DBC-GGZ. HelloID kan dit lidmaatschap indien nodig ook weer intrekken.|



## Ysis via HelloID koppelen met systemen

HelloID maakt het mogelijk diverse andere systemen met Ysis te integreren, waaronder diverse bronsystemen. Met behulp van de integraties verbeter je het beheer van gebruikersaccounts en autorisaties. Voorbeelden van veelvoorkomende integraties zijn: 

* **Microsoft Active Directory/Entra ID - Ysis koppeling:** Versterk je beveiliging en de gebruikerservaring die je biedt door Ysis en Active Directory via HelloID volledig in sync te houden met het oog op Single Sign-on (SSO). Zo hoeven gebruikers slechts eenmaal in te loggen om toegang te krijgen tot de accounts die zij nodig hebben, waaronder hun Ysis-account. Ook hoeven gebruikers minder wachtwoorden te onthouden, waardoor zij eenvoudiger sterke wachtwoorden kunnen gebruiken. Dit verhoogt de productiviteit, verbetert de beveiliging en vereenvoudigt het beheer van gebruikersaccounts en autorisaties. 

* **AFAS - Ysis koppeling:** De koppeling tussen AFAS en YSIS verbetert de samenwerking tussen de HR- en IT-afdeling. HelloID kan bijvoorbeeld bij indiensttreding van een medewerker automatisch een Ysis-account aanmaken, en de bijbehorende Ysis-rol en/of -module aan dit account koppelen. Dit maakt het accountprovisioningproces soepeler en efficiënter.

HelloID ondersteunt ruim 200 connectoren, wat een breed scala aan integratiemogelijkheden biedt tussen je bronsystemen en Ysis. We breiden ons portfolio met connectoren en integraties voortdurend uit. Je kunt HelloID dan ook integreren met nagenoeg ieder populair systeem. Wil je meer weten over de mogelijkheden? Een overzicht van alle beschikbare connectoren vind je [hier](https://www.tools4ever.nl/connectoren/).
