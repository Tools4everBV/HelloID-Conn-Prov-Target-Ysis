The Ysis Target Connect enables Ysis to connect to various source systems via Tools4ever's identity & access management (IAM) solution HelloID. The integration strengthens and streamlines the management of access rights and user accounts, with automation taking centre stage. In doing so, HelloID always relies on data it retrieves from your source systems. In this article, we elaborate on the features and benefits of the Ysis Target connector. 

# What is Ysis

Ysis is software developed by Gerimedica. The software supports the complex care needed by vulnerable people. It is estimated that about half of all practitioners in the sector use Ysis. About 30,000 healthcare professionals log into the solution every day. Ysis minimises the time healthcare professionals spend behind a screen, leaving them more time to deliver healthcare. The solution is tailored to the needs of doctors, nurses, practitioners and care workers in elderly care, district care and disability care. It also supports professionals handling the administration and billing of care provided. 

# Why is a Ysis connector useful?

Ysis plays an important role in delivering the right care for vulnerable people. It’s therefore very important that all employees, whether permanent, temporary, or agency staff, have access to Ysis. With the integration between your source systems and Ysis via HelloID, you don’t need to spend time on this. The IAM solution automatically detects changes in your source systems, whether it involves creating a new user or a change in job function. Based on this, HelloID automatically creates or updates the right account in Ysis. Note: mutating disciplines directly from Ysis is not possible.

The integration saves a lot of time and ensures uniform procedures. Tijmen Lodders, an IT employee at Stichting tanteLouise, explains: “Previously, we created accounts manually and assigned permissions ourselves. Now, we've linked these to roles and HelloID automates everything for us. We no longer need to do anything except check twice a week to ensure it's all still working properly. Before, we spent about 20 minutes per account. That's just not necessary anymore."

The Ysis connector enables integrations with common systems. For example: 
*	Active Directory/Entra ID
*	AFAS

You can find more information about the integration with these source systems later in this article.

# HelloID for Ysis helps you with

**Faster account creation:** The integration between your source systems and Ysis via HelloID speeds up the creation of the Ysis accounts your employees need. The IAM solution automates this process, freeing you from having to manage it. It ensures that new employees can immediately start working from their first day.

**Error-free account management:** HelloID links the user's email address to the Ysis account based on the relevant account—either Active Directory or Entra ID. The IAM solution follows strict procedures. This ensures that all required steps are completed while also reducing the likelihood of errors. HelloID also logs all user activity and authorisations in a log file. This allows you to consistently demonstrate compliance with regulatory requirements.

**Increased service levels and security:** The connection between your source systems and Ysis also improves your security level. Thanks to the connector, accounts of former employees never remain active unintentionally. This is important, as it provides potential attackers opportunities that are avoidable. At the same time, the integration improves your service level by quickly providing users with the required Ysis accounts and processing changes immediately. It also means you spend less time correcting errors.

# How HelloID integrates with Ysis

You can link Ysis as a target system to HelloID. The IAM solution utilises the Ysis API, which is based on the System for Cross-domain Identity Management (SCIM). Ysis uses whitelisting for this API, meaning that an on-premises HelloID agent is required to establish this connection.

Note: HelloID can initially set which discipline a Ysis account belongs to, but it cannot automatically update this discipline when changes occur. HelloID does detect changes in the discipline from your source system and can notify Ysis's functional manager via email. The functional manager can then manually process the change.

| Change in source system	| Procedure in Ysis |
| ------------------------ | ---------------- | 
| New employee |	When a new employee joins the company, HelloID detects the change in your source systems. Based on this change in, HelloID automatically creates the required user account in Ysis. This enables new employees to get started immediately.|
| Change in employee data |	HelloID automatically detects changes in your source system data and can update these in Ysis. This includes changes such as an employee changing their name after getting married. Note: HelloID cannot automatically update a discipline within Ysis.|
| Employee changes job role |	Based on information from your source systems, HelloID can assign a Ysis account to a specific module and/or role within Ysis. For example, to enable invoicing for primary paramedical care, DBC-GRZ, and DBC-GGZ. HelloID can also revoke this membership if necessary.|


# Connecting Ysis to systems via HelloID

HelloID enables the integration of various other systems with Ysis, including multiple source systems. Using the integrations, you improve the management of user accounts and authorisations. Examples of common integrations are: 

* **Microsoft Active Directory/Entra ID - Ysis connector:** Enhance your security and improve the user experience you offer in Ysis and Active Directory via Hello

Improve your security and the user experience you offer by keeping Ysis and Active Directory fully synchronised through HelloID for Single Sign-On (SSO). This way, users need to only log in once to access the accounts they need, including their Ysis account. Users also need to remember fewer passwords, making it easier for users to use strong passwords. This increases productivity, improves security, and simplifies the management of user accounts and authorisations.

* **AFAS – Ysis connector:** The connection between AFAS and Ysis improves the cooperation between the HR and IT departments. For example, HelloID can automatically create a Ysis account when an employee joins, and link the corresponding Ysis role and/or module to this account. This makes the account provisioning process smoother and more efficient.

HelloID supports more than 200 connectors, offering a broad range of options to integrate your source systems and Ysis. We are continuously expanding our portfolio of connectors and integrations. You can therefore integrate HelloID with almost any popular system. Would you like to know more about the possibilities? 
