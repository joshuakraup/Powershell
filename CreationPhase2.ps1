<#
This script represents phase 2 of the user creation script. 
The following tasks need to be accomplished

- Check to see the user exists and then assign a license
        The script will pause until it identifies a synced user.

Ver 0.1 (Heavy Re-writes still required)

Author: Joshua Raup


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
Import-PSSession $session

Write-Host "Connected..."

}

## Heavy editing and rewrite potentially needed to accomplish this section. 
function Check-User {
            # User first needs to be assigned a region, then a license.
            Set-AzureADUser -ObjectId "$FirstName.$LastName@nacgroup.com" -UsageLocation US
            $LicenseSku = Get-AzureADSubscribedSku | Where-Object {$_.SkuPartNumber -eq 'O365_BUSINESS_PREMIUM'}
            $License = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
            $License.SkuId = $LicenseSku.SkuId
            $AssignedLicenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
            $AssignedLicenses.AddLicenses = $License
            Set-AzureADUserLicense -ObjectId "$FirstName.$LastName@nacgroup.com" -AssignedLicenses $AssignedLicenses

            start-sleep -Seconds 120
}

function AddTo-Sharepoint {
Start-Sleep -Seconds 300
Add-SPOUser -Site https://nacgroup.sharepoint.com -LoginName "$FirstName.$LastName@nacgroup.com" -Group "Team Site Members"
}

function AddTo-Groups ([string]$Division){
#import the Division from the parameters
#Pull list of the groups, extract the displayname property and store that inside a variable

$365Group = get-unifiedgroup | where {$_.DisplayName -match $Division} | select DisplayName

#While the variable itself is a PSCustomObject typ the property inside is a system.string type so we dont need to convert

Add-UnifiedGroupLinks -Identity $365Group.DisplayName -Links $UserEmail -LinkType Members


}


#start the detection and gather users for changes
#detect and record users whose country value is set as 1
$changeUsers = get-aduser | ? {$_.Country -eq "1"}

#loop through the functions for each user that contains the country value of '1'
foreach($user in $changeUsers){

#connect to the o365 tenant using the service user
Connect-Office365
#check the user 
Check-User
#Add user to sharepoint
AddTo-Sharepoint
#Add user to Groups
AddTo-Groups
}