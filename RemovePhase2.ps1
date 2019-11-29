﻿<# Remove phase 2

Script is responsible for taking care of phase 2 of removal

This phase includes the following functions

Putting the user on an in place hold

#>

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
Import-PSSession $session -ErrorAction SilentlyContinue

}


function Hold-Mailbox { 

$RemovalOfUsers = get-aduser -filter * -properties * | ? {$_.EmployeeID -eq "6"}

    foreach($user in $RemovalOfUsers){

    $UPN = $user.userprincipalname
    #Connect to the Security and Compliance Center

    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.compliance.protection.outlook.com/powershell-liveid -Credential $MsolCredential -Authentication Basic -AllowRedirection

    New-MailboxSearch -Name "$user.userprincipalname Archive" -SourceMailboxes $user.userprincipalname -InPlaceHoldEnabled $true
    set-aduser $user.userprincipalname -EmployeeID "5"
    #as of yet i don't have a good way to capture their entire onedrive. The cmdlets for sharepoint are lacking. Either way I can't export it. However by default the manager of the user get's access following deletion of the user.
    }
}

import-module -Name PowershellGet
import-module -Name AzureAD

Connect-Office365

Hold-Mailbox



