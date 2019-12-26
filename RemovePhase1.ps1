function Connect-Office365 {

Write-Host "Connect to 365. You'll provide your credentials twice"

# Pull credentials before moving to Office 365.
$TenantUname = “SVC_SCRIPTS@nacgroup.com”
$TenantPass = cat “C:\Scripts\Exchange_Online\Password.txt” | ConvertTo-SecureString -AsPlainText -Force
$Script:TenantCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $TenantUname, $TenantPass
$msoExchangeURL = “https://ps.outlook.com/powershell/”                                              

#Connect to cloud services
# Sourced from https://docs.microsoft.com/en-us/powershell/azure/active-directory/enabling-licenses-sample?view=azureadps-2.0 on 11 Jan 2019.
Connect-MsolService -Credential $TenantCredentials
Connect-AzureAD -Credential $TenantCredentials
Connect-SPOService -Url https://nacgroup-admin.sharepoint.com -Credential $TenantCredentials

$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $msoExchangeURL -Credential $TenantCredentials -Authentication Basic -AllowRedirection
Import-PSSession $session -ErrorAction SilentlyContinue
}


Function Generate-Password (){
Param (

[int]$length = 9
)
$ascii=$NULL;For ($a=33;$a –le 126;$a++) {$ascii+=,[char][byte]$a }

For ($loop = 1; $loop -le $length; $loop++){

    $Script:TempPass += ($ascii | Get-Random)

    }
}

Function Disable-MailLogon {
#disable the logon
#$ObjectID = get-msoluser -UserPrincipalName $UPN | select ObjectID ##This may not be necessary because the scope was the problem.
set-msoluser -UserPrincipalName $user.userprincipalname -BlockCredential $true


}

Function Set-UserPass(){
<#
Function is to gather manager information, set the password of the user, and then notify the manager. In addition, it needs to write the password to a password protected file on the network drive. Ideally an excel spreadsheet

The excel spreadsheet must include
    Username
    Email
    Password
    Date the Deletion was requested
    Date the deletion will take full effect
#>
#[string]$Manager = Get-ADUser -identity $Username | select Manager
Set-ADAccountPassword -Identity $User.DistinguishedName -NewPassword (ConvertTo-SecureString -AsPlainText $TempPass -Force) -Reset 

$userManagerEmail = get-aduser -filter * | Where-Object { $_.DisplayName -like "$user.manager" } | select WindowsEmailAddress
$smtpCred = $tenantcredentials 
$toAddress = $userManagerEmail
$fromAddress = "svc_scripts@nacgroup.com"
$smtpServer = 'smtp.office365.com'
$bodyAndSubject = $User.DisplayName

Send-MailMessage `
-From $fromAddress `
-To $toAddress `
-Subject 'User Account Removal' `
-Body "The user $bodyAndSubject is being tagged for removal. As a result, the password has been changed. As the manager, the current password is sent to you. Current Pass: $TempPass" `
-SmtpServer $smtpServer `
-Credential $smtpCred  `
-UseSsl

}

Function Set-UserProperty {

Set-ADUser -Identity $user.distinguishedname -EmployeeID "6"

}


$UserstobeRemoved = get-aduser -filter * -properties * | ? {$_.EmployeeID -eq "5"}

foreach($user in $UserstobeRemoved){
Connect-Office365

Generate-Password

Disable-MailLogon

Set-UserPass

Set-UserProperty
}