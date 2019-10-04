<#
This script represents phase 2 of the user creation script. 
The following tasks need to be accomplished

- Check to see the user exists and then assign a license
        The script will pause until it identifies a synced user.

Ver 0.1 (Heavy Re-writes still required)

Author: Joshua Raup


#>

import-module ActiveDirectory
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

Write-Host "Connected..."

}

## Heavy editing and rewrite potentially needed to accomplish this section. 
function Check-User {
                # User first needs to be assigned a region, then a license.
                
                Set-AzureADUser -ObjectId $User.UserPrincipalName -UsageLocation US
                $LicenseSku = Get-AzureADSubscribedSku | Where-Object {$_.SkuPartNumber -eq 'O365_BUSINESS_PREMIUM'}
                $License = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
                $License.SkuId = $LicenseSku.SkuId
                $AssignedLicenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
                $AssignedLicenses.AddLicenses = $License
                Set-AzureADUserLicense -ObjectId $user.UserPrincipalName -AssignedLicenses $AssignedLicenses
                
           
}

function AddTo-Sharepoint {
  
    Add-SPOUser -Site https://nacgroup.sharepoint.com -LoginName $user.UserPrincipalName -Group "Team Site Members"
    
}

function AddTo-UserSelectionGroups {

    switch ($user.EmployeeID)
    {
        1 {
            
        }
        2 {
            add-adgroupmember -identity LAN-Access -members $user.userprincipalname
        }
        4{
            $app_name = "GoCanvas-SSO"
            $app_role_name = "User"
            $UserObjectID = get-azureaduser -SearchString "$user.userprincipalname"
            $sp = Get-AzureADServicePrincipal -Filter "displayName eq '$app_name'"
            $appRole = $sp.AppRoles | Where-Object { $_.DisplayName -eq $app_role_name }
            New-AzureADUserAppRoleAssignment -ObjectId $user.ObjectId -PrincipalId $user.ObjectId -ResourceId $sp.ObjectId -Id $appRole.Id
        }
        5 {
            add-adgroupmember -identity LAN-Access -members $user.userprincipalname
            $app_name = "GoCanvas-SSO"
            $app_role_name = "User"
            $UserObjectID = get-azureaduser -SearchString "$user.userprincipalname"
            $sp = Get-AzureADServicePrincipal -Filter "displayName eq '$app_name'"
            $appRole = $sp.AppRoles | Where-Object { $_.DisplayName -eq $app_role_name }
            New-AzureADUserAppRoleAssignment -ObjectId $user.ObjectId -PrincipalId $user.ObjectId -ResourceId $sp.ObjectId -Id $appRole.Id
        }
    }

}

function AddTo-Groups{
#import the Division from the parameters
#Pull list of the groups, extract the displayname property and store that inside a variable
$TenantUname = “SVC_SCRIPTS@nacgroup.com”
$TenantPass = cat “C:\Scripts\Exchange_Online\Password.txt” | ConvertTo-SecureString -AsPlainText -Force
$TenantCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $TenantUname, $TenantPass
$msoExchangeURL = “https://outlook.office365.com/powershell-liveid/”  
$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $msoExchangeURL -Credential $TenantCredentials -Authentication Basic -AllowRedirection
Import-PSSession $session

$365Group = get-unifiedgroup | where {$_.DisplayName -match $user.Department} | select DisplayName

#While the variable itself is a PSCustomObject typ the property inside is a system.string type so we dont need to convert

Add-UnifiedGroupLinks -Identity $365Group.DisplayName -Links $user.UserPrincipalName -LinkType Members

}

function AddUserToGoCanvasEnterpriseApplication{
# Assign the values to the variables
$app_name = "GoCanvas-SSO"
$app_role_name = "User"

# Get the user to assign, and the service principal for the app to assign to
$azuser = Get-AzureADUser -ObjectId $user.UserPrincipalName
$sp = Get-AzureADServicePrincipal -Filter "displayName eq '$app_name'"
$appRole = $sp.AppRoles | Where-Object { $_.DisplayName -eq $app_role_name }

# Assign the user to the app role
New-AzureADUserAppRoleAssignment -ObjectId $azuser.ObjectId -PrincipalId $azuser.ObjectId -ResourceId $sp.ObjectId -Id $appRole.Id

set-aduser $user -EmployeeID "2"
}
#start the detection and gather users for changes
#detect and record users whose country value is set as 1
$changeUsers = get-aduser -filter {(EmployeeID -eq '1') -or (EmployeeID -eq '2') -or (EmployeeID -eq '3')} -Properties *

#loop through the functions for each user that contains the employeeID of '1'
foreach($user in $changeUsers){
#connect to the o365 tenant using the service user
Connect-Office365
#check the user 
Check-User
#Add user to sharepoint
AddTo-Sharepoint
#Add user to Groups
AddTo-Groups
#Add user to user selection groups (ID has a specifc value.)
AddTo-UserSelectionGroups
#add user to GoCanvas
AddUserToGoCanvasEnterpriseApplication
}