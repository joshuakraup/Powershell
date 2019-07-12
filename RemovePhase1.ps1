function Connect-Office365 {

Write-Host "Connect to 365. You'll provide your credentials twice"

# Pull credentials before moving to Office 365.
$TenantUname = “SVC_SCRIPTS@nacgroup.com”
$TenantPass = cat “C:\Scripts\Exchange_Online\Password.txt” | ConvertTo-SecureString -AsPlainText -Force
$TenantCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $TenantUname, $TenantPass
$msoExchangeURL = “https://ps.outlook.com/powershell/”                                              

#Connect to cloud services
# Sourced from https://docs.microsoft.com/en-us/powershell/azure/active-directory/enabling-licenses-sample?view=azureadps-2.0 on 11 Jan 2019.
Connect-MsolService -Credential $TenantCredentials
Connect-AzureAD -Credential $TenantCredentials
Connect-SPOService -Url https://nacgroup-admin.sharepoint.com -Credential $TenantCredentials

$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $msoExchangeURL -Credential $TenantCredentials -Authentication Basic -AllowRedirection
Import-PSSession $session

Write-Host "Connected..."

}


Function Get-Username(){

Write-Host "Welcome to the NAC User Removal Script. We only need a little info to start the process."
$Global:Username = Read-Host "Please Enter the Username of the user without the @nacgroup.com part"

$Global:UPN = $Username + "@nacgroup.com"

}


Function Generate-Password (){
Param (

[int]$length = 9
)
$ascii=$NULL;For ($a=33;$a –le 126;$a++) {$ascii+=,[char][byte]$a }

For ($loop = 1; $loop -le $length; $loop++){

    $Global:TempPass += ($ascii | Get-Random)

    }
}

Function Disable-MailLogon {
Write-Host "Test passing variable for UPN" + $UPN
#disable the logon
#$ObjectID = get-msoluser -UserPrincipalName $UPN | select ObjectID##This may not be necessary because the scope was the problem.
set-msoluser -UserPrincipalName $UPN -BlockCredential $true

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
[string]$Manager = Get-ADUser -identity $Username | select Manager
Set-ADAccountPassword -Identity $Username -NewPassword (ConvertTo-SecureString -AsPlainText $TempPass -Force) -Reset 
}

Function Set-UserProperty {

set-aduser $UPN -replace @{CustomAttribute1 ="0001"}

}


if (get-module -listavailable -name PowershellGet,PackageManagement,AzureAD,Microsoft.SharePointOnline.CSOM){
Connect-Office365

Generate-Password

Disable-MailLogon

Set-UserPass
}
else {
Write-Host "Needed modules do not exist on the machine. Installing now"
import-module -Name PowershellGet
import-module -Name AzureAD
install-package -Name Microsoft.SharePointOnline.CSOM

Connect-Office365

Generate-Password

Disable-MailLogon

Set-UserPass


}