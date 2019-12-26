<# Remove phase 2

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
    
    $mySiteDomain = "nacgroup"
    $names = $user.DisplayName
    $holdname = "Offboarding $names"
    $casename = "Offboarding $names Case"

    $AdminUrl = "https://$mySiteDomain-admin.sharepoint.com"
    $mySiteUrlRoot = "https://$mySiteDomain-my.sharepoint.com"
    # Add the path of the User Profile Service to the SPO admin URL, then create a new webservice proxy to access it
    $proxyaddr = "$AdminUrl/_vti_bin/UserProfileService.asmx?wsdl"
    $UserProfileService= New-WebServiceProxy -Uri $proxyaddr -UseDefaultCredential False
    $UserProfileService.Credentials = $credentials
    # Take care of auth cookies
    $strAuthCookie = $spCreds.GetAuthenticationCookie($AdminUrl)
    $uri = New-Object System.Uri($AdminUrl)
    $container = New-Object System.Net.CookieContainer
    $container.SetCookies($uri, $strAuthCookie)
    $UserProfileService.CookieContainer = $container
    $urls = @()
    
    try{
        $prop = $UserProfileService.GetUserProfileByName("i:0#.f|membership|$emailAddress") | Where-Object { $_.Name -eq "PersonalSpace" }
        $url = $prop.values[0].value
  	if($url -ne $null){
        $furl = $mySiteUrlRoot + $url
        $urls += $furl
        Write-Host "- $emailAddress => $furl"
  	[array]$ODadded += $furl}
    else{    
        Write-Warning "Couldn't locate OneDrive for $emailAddress"
  	[array]$ODExluded += $emailAddress
    }}
    catch { 
    Write-Warning "Could not locate OneDrive for $emailAddress"
    [array]$ODExluded += $emailAddress
    Continue }

    New-CaseHoldPolicy -Name "$holdName" -Case "$casename" -ExchangeLocation $finallist -SharePointLocation $urls -Enabled $True | out-null
    New-CaseHoldRule -Name "$holdName" -Policy "$holdname" -ContentMatchQuery $holdQuery | out-null

    $newhold=Get-CaseHoldPolicy -Identity "$holdname" -Case "$casename" -erroraction SilentlyContinue
    $newholdrule=Get-CaseHoldRule -Identity "$holdName" -erroraction SilentlyContinue
    }
}

import-module -Name PowershellGet
import-module -Name AzureAD

Connect-Office365

Hold-Mailbox



