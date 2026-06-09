De Ysis Target Connect ermöglicht es, Ysis über die Identity & Access Management (IAM)-Lösung HelloID von Tools4ever mit verschiedenen Quellsystemen zu verbinden. Die Integration stärkt und optimiert insbesondere die Verwaltung von Zugriffsrechten und Benutzerkonten, wobei die Automatisierung im Vordergrund steht. HelloID basiert stets auf Daten, die es aus Ihren Quellsystemen bezieht. In diesem Artikel erörtern wir die Möglichkeiten und Vorteile des Ysis Target Connectors.

## Was ist Ysis?

Ysis ist eine von Gerimedica entwickelte Software. Die Software unterstützt die komplexe Pflege, die verletzliche Personen benötigen. Schätzungen zufolge nutzt etwa die Hälfte aller Behandler im Sektor Ysis; täglich loggen sich rund 30.000 Pflegefachkräfte in die Lösung ein. Ysis minimiert die Zeit, die Pflegefachkräfte vor dem Bildschirm verbringen, sodass sie mehr Zeit für die Patientenpflege haben. Die Lösung ist auf die Bedürfnisse von Ärzten, Krankenschwestern, Therapeuten und Pflegekräften in der Alten-, Gemeinde- und Behindertenpflege abgestimmt. Dabei berücksichtigt sie auch Fachkräfte, die sich um die Verwaltung und Abrechnung erbrachter Pflegeleistungen kümmern.

## Warum ist die Ysis-Verbindung nützlich?

Ysis spielt eine entscheidende Rolle bei der Bereitstellung angemessener Pflege für schutzbedürftige Menschen. Es ist daher von größter Bedeutung, dass Mitarbeiter, ob Festangestellte, Zeitarbeiter oder Leiharbeiter, Zugang zu Ysis haben. Dank der Verbindung zwischen Ihren Quellsystemen und Ysis über HelloID müssen Sie sich darum keine Sorgen machen. Die IAM-Lösung erkennt automatisch Änderungen in Ihren Quellsystemen, unabhängig davon, ob es sich um die Erstellung eines neuen Benutzers oder eine Funktionsänderung handelt. Auf dieser Basis erstellt HelloID das erforderliche Konto in Ysis automatisiert oder verändert ein bestehendes Konto. Hinweis: Die Änderung von Disziplinen ist aus Ysis heraus nicht möglich.

Die Anbindung spart viel Zeit und sorgt für eine einheitliche Arbeitsweise. Tijmen Lodders, IT-Mitarbeiter bei der Stiftung TanteLouise, erläutert:

**_„Früher haben wir manuell Konten erstellt und Rechte zugeordnet. Jetzt haben wir das auf Rollen umgestellt und alles wird von HelloID automatisiert. Wir müssen uns um nichts mehr kümmern. Ich prüfe nur noch zweimal pro Woche, ob alles noch funktioniert, aber das ist alles. Früher haben wir pro Konto etwa 20 Minuten benötigt. Das ist jetzt einfach nicht mehr nötig."“_**

Der Ysis Connector ermöglicht Integrationen mit weit verbreiteten Systemen wie:

* Active Directory/Entra ID
* AFAS

Weitere Informationen zur Integration mit diesen Quellsystemen finden Sie weiter unten in diesem Artikel.

## HelloID für Ysis hilft Ihnen bei

**Beschleunigte Kontoerstellung:** Die Verbindung zwischen Ihren Quellsystemen und Ysis über HelloID ermöglicht es, die für Mitarbeiter erforderlichen Ysis-Konten schneller zu erstellen. Die IAM-Lösung automatisiert diesen Prozess, sodass Sie sich keine Sorgen machen müssen. So können Sie sicherstellen, dass neue Mitarbeiter an ihrem ersten Arbeitstag direkt einsatzbereit sind.

**Fehlerfreie Kontoverwaltung:** HelloID verknüpft das Nutzerkonto – Active Directory oder Entra ID – mit der E-Mail-Adresse des Nutzers für das Ysis-Konto. Die IAM-Lösung verwendet feste Verfahren, sodass Sie immer sicher sein können, dass alle erforderlichen Schritte durchgeführt werden, und gleichzeitig die Fehleranfälligkeit reduziert wird. Auch dokumentiert HelloID alle Aktivitäten im Zusammenhang mit Benutzern oder Berechtigungen in einer Logdatei. So können Sie jederzeit nachweisen, dass Sie die geltenden Compliance-Anforderungen erfüllen.

**Verbesserte Servicelevels und Sicherheit:** Die Verbindung zwischen Ihren Quellsystemen und Ysis verbessert auch Ihr Sicherheitsniveau. So stellen Sie sicher, dass Konten ehemaliger Mitarbeiter nie unbeabsichtigt aktiv bleiben. Dies ist wichtig, da Sie dadurch potenziellen Angreifern unnötige Chancen bieten. Gleichzeitig verbessert die Anbindung Ihr Servicelevel. Nutzer erhalten schneller das benötigte Ysis-Konto und Änderungen werden schneller verarbeitet. Dadurch werden vermeidbare Fehler reduziert, die Benutzerzufriedenheit erhöht und weniger Zeit für die Fehlerkorrektur aufgewendet.

## Wie HelloID mit Ysis integriert

Sie können Ysis als Zielsystem an HelloID anbinden. Die IAM-Lösung verwendet dabei die API von Ysis, die auf System for Cross-domain Identity Management (SCIM) basiert. Für die Nutzung dieser API verwendet Ysis eine Whitelist. Dies bedeutet in der Praxis, dass ein On-Premises HelloID-Agent erforderlich ist, um diese Verbindung herzustellen.

Hinweis: HelloID kann initial festlegen, zu welcher Disziplin ein Ysis-Konto gehört, kann diese Disziplin aber bei Änderungen nicht automatisch aktualisieren. HelloID erkennt die Änderung der Disziplin in Ihrem Quellsystem jedoch und kann den funktionalen Ysis-Administrator per E-Mail informieren. Der funktionale Administrator kann die Änderung anschließend manuell verarbeiten.

| Änderung im Quellsystem |	Verfahren in Ysis |
| ------------------------ | ------------------ |
| **Neuer Mitarbeiter** | Trifft ein neuer Mitarbeiter ein? HelloID erkennt dies in Ihren Quellsystemen und erstellt automatisch das erforderliche Benutzerkonto in Ysis. So können neue Mitarbeiter direkt loslegen. |
| **Änderung von Mitarbeiterdaten** | HelloID erkennt automatisch Änderungen der Daten in Ihrem Quellsystem und kann diese in Ysis verarbeiten. Denken Sie dabei an den Namen eines Mitarbeiters, zum Beispiel, wenn er oder sie geheiratet hat. Hinweis: HelloID kann eine Disziplin in Ysis nicht automatisiert aktualisieren. |
| **Funktion des Mitarbeiters ändert sich** | Auf Basis der Informationen aus Ihren Quellsystemen kann HelloID ein Ysis-Konto einem bestimmten Modul und/oder einer Rolle in Ysis hinzufügen. Zum Beispiel, um Abrechnungen für primärärztliche Paramedi-Verwaltung, die DBC-GRZ und die DBC-GGZ zu ermöglichen. HelloID kann diese Mitgliedschaft bei Bedarf auch wieder entziehen. |

## Ysis über HelloID mit Systemen verbinden

HelloID ermöglicht es, verschiedene andere Systeme mit Ysis zu integrieren, einschließlich verschiedener Quellsysteme. Mit Hilfe dieser Integrationen verbessern Sie das Management von Benutzerkonten und Berechtigungen. Zu den häufigen Integrationen gehören:

* **Microsoft Active Directory/Entra ID - Ysis-Anbindung:** Stärken Sie Ihre Sicherheit und die Benutzerfreundlichkeit, die Sie bieten, indem Sie Ysis und Active Directory über HelloID vollständig synchronisiert halten, mit dem Fokus auf Single Sign-On (SSO). Damit müssen sich Benutzer nur einmal anmelden, um Zugriff auf die benötigten Konten zu erhalten, einschließlich ihres Ysis-Kontos. Nutzer müssen sich auch weniger Passwörter merken, wodurch sie einfacher starke Passwörter verwenden können. Dies erhöht die Produktivität, verbessert die Sicherheit und vereinfacht die Verwaltung von Benutzerkonten und Berechtigungen.

* **AFAS - Ysis-Anbindung:** Die Verbindung zwischen AFAS und YSIS verbessert die Zusammenarbeit zwischen der Personal- und IT-Abteilung. HelloID kann beispielsweise bei der Einstellung eines Mitarbeiters automatisch ein Ysis-Konto erstellen und die zugehörige Ysis-Rolle und/oder -Modul mit diesem Konto verknüpfen. Dies macht den Account-Provisioning-Prozess reibungsloser und effizienter.

HelloID unterstützt über 200 Konnektoren, was ein breites Spektrum an Integrationsmöglichkeiten zwischen Ihren Quellsystemen und Ysis bietet. Wir erweitern unser Portfolio an Konnektoren und Integrationen ständig. Sie können HelloID daher nahezu mit jedem gängigen System integrieren. Möchten Sie mehr über die Möglichkeiten erfahren? Eine Übersicht aller verfügbaren Konnektoren finden Sie [hier](https://www.tools4ever.nl/connectoren/).