|Field Ysis|Mandatory|SCIM request|Formula|Remarks|
| ------------ | ----------- | ------------ | ----------- |----------- |
| iam_id | yes* | schemas.id | | *) mandatory for SCIM, not for Ysis |
|First names|yes|name.givenName||
|Insertions||-||
|Last name|yes|name.familyName||
|Initials|yes|name.givenName|First character of each first name, separated by space|
|Sex||-|='Onbekend'|
|User name|yes|userName||
|Ysis initials|yes|name.givenName|see Initials|if Initials not unique, add sequence number 1.2.3…?
|Personnel number||employeeNumber|part of enterprise user extension|see user.json example
|AGB code||agbcode|part of ysis user extension|
|BIG number||bignummer|part of ysis user extension|
|phone number||phoneNumbers|select the one with type="work"|
|Mobile number||phoneNumbers|select the one with type="mobile"|
|E-mail address||emails|only first emailaddress is stored|Ysis only know one emailaddress
|Export timeline events to calendar||-|='TRUE'|
|Discipline|yes|userType||
|Function||function|part of ysis user extension|
|Profession||profession|part of ysis user extension|need to be on of COD878-DBCO, see https://www.vektis.nl/standaardisatie/codelijsten/|COD878-DBCO
|End date||current date|only set if delete request or active state=false|
|General comment||-||
|password|yes|password|autogenerate|unknown to the user
|active state||active|true=active user, false=blocked user|
|profile photo||photos|select the one with type="photo"|not for version 1
|authorisations||authorisations|part of ysis user extension|see user.json example

