<# add user script phase 1


This script is responsible for the follow up value addition and creation of a new user in a domain.
Script assumes the user exists both on prem and in 365 as well as Azure AD.

All variables will have predefined values. A later script will dynamically retrieve those values. 

Author: Joshua Raup

#>


function Create-LocalUser ([string]$UserEmail) {

#Retrieve Input from the User
### Must figure out a more efficient way to ask the questions and get the answers if possible. This is just kind of ridiculous. Maybe a "do you want to enter optional info if statement ###
$alldepartments = get-adobject -SearchBase 'OU=Users,OU=MyBusiness,DC=nac,DC=local' -SearchScope OneLevel -Filter 'ObjectClass -eq "organizationalunit"'

$global:FirstName = Read-Host "Enter the First Name"
$global:LastName = Read-Host "Enter the Last Name"
$global:FourDigits = Read-Host "Last Four of the User"
$global:Division = Read-Host "Enter the Department of the User(Required)"
Write-Host $alldepartments.name
$global:LANAccessGrp = Read-Host "Do you want the user in the LAN-Access Group (y/n)"
$global:CanvasGrp = Read-Host "Do you want the user in the Canvas SSO Group (y/n)"
$global:Manager = Read-Host "Who is the User's Manager(not required. Can leave blank)"
$global:EmployeeNumber = Read-Host "What is the employee number of the user(not required. Can leave blank)"
$global:MobilePhone = Read-Host "What is the mobile phone number(not required. Can leave blank)"
$global:Description = Read-Host "Enter the Job Title of the user (not required. Can leave blank)"
$global:UserEmail = "$FirstName.$LastName@nacgroup.com"

# Combine the variables as needed and add info where needed to complete the formatting (edited for clarity)
$UserName = "$FirstName.$LastName"
$ManagerCN = Get-ADUser -filter * | ? ($_.userprincipalname -like $Manager)
$ProfilePath = ($UserTemplate.DistinguishedName -split ",",2)[1]

# Initial user account creation.
Write-Host "Creating User and setting information."
New-ADUser -SamAccountName $UserName -Name "$FirstName $LastName"

# Set user properties: Description, DisplayName, EmailAddress, EmployeeNumber, GivenName, Manager, MobilePhone, Surname, UserPrincipalName.
Set-ADUser -Identity $Username -Description "$Description"
Set-ADUser -Identity $Username -DisplayName "$FirstName $LastName"
Set-ADUser -Identity $Username -EmailAddress "$UserName@nacgroup.com"
Set-ADUser -Identity $UserName -GivenName $FirstName
Set-ADUser -Identity $UserName -Manager $ManagerCN
Set-ADUser -Identity $UserName -Surname $LastName
Set-ADUser -Identity $UserName -UserPrincipalName "$FirstName.$LastName@nacgroup.com"

    switch($LANAccessGrp,$canvasGrp)
        {
            ($LANAccessGrp -eq 'y' -or 'Y') {$LANAccessSetting = 1}
            ($LANAccessGrp -eq 'n' -or 'N') {$LANAccessSetting = 0}
            ($CanvasGrp -eq 'y' -or 'Y') {$CanvasSetting = 3}
            ($CanvasGrp -eq 'n' -or 'N') {$CanvasSetting = 0}
        }

$UserValue = 1 + $LANAccessSetting + $CanvasSetting   
Set-ADUser -Identity $UserName -EmployeeID "$UserValue"

# Move to correct OU.
Get-ADUser -Identity $UserName | Move-ADObject -TargetPath $ProfilePath

# Set proxy address(es).
Write-Host "Setting Proxy Addresses"
Get-ADUser -Identity $UserName | Set-ADUser -Add @{ProxyAddresses="SMTP:$UserEmail"}

# Reset user password and enable account.
Write-Host "Setting User Password"
Set-ADAccountPassword -Identity $UserName -Reset
Set-ADUser -Identity $UserName -Enabled $True

Write-Host "Pushing information to Microsoft Online..."

# Sync the newly created user to Office 365 and Azure AD
start-adsyncsynccycle -policytype delta

}

#Function for Connection to O365 via the service user. 
function Connect-Office365 {

Write-Host "Connect to 365. You'll provide your credentials twice"

# Pull credentials before moving to Office 365.
$TenantCredentials = Get-Credential
$msoExchangeURL = “https://outlook.office365.com/powershell-liveid/”                                              

#Connect to cloud services
# Sourced from https://docs.microsoft.com/en-us/powershell/azure/active-directory/enabling-licenses-sample?view=azureadps-2.0 on 11 Jan 2019.
Connect-MsolService -Credential $TenantCredentials



$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $msoExchangeURL -Credential $TenantCredentials -Authentication Basic -AllowRedirection
Import-PSSession $session

Write-Host "Connected..."

}




Connect-Office365

Create-LocalUser







