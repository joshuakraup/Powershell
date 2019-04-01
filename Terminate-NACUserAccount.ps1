
<#

Tasks to accomplish:

-----Part One of this task-----
 x Change password to random value (Partly Done)
 - Write new password value to some location (for manager to review data)
 x Disable mail logon
 x Remove from Office 365 groups
 X Remove from SharePoint access
 X Download a copy of mailbox (can't do this via powershell. Can create the hold, just can't export)
 / Download a copy of OneDrive (looking into ways to set retention but I can't export this)
 / Download a copy of user account on assigned computer(s)
 / Archive all to a cool storage location (Possibly use the e-discovery system in security and compliance? Even though it's not SUPPOSED to do that)

 Blocker: We don't appear to have good access to the Security and Compliance Center version of the compliance management tools. 

 -----Part Two of this task-----

 This is going to have to get separated into a separate task. The problem with that is that it means we have to figure out a method to automate this part. 
 Two options, save a excel sheet of user emails that have been separated that, if they still exist, to check the amount of time since they were last logged into/last modified and then run the requisite step
 Option two is to figure out how to setup various breakpoints of user accounts (which im pretty sure isn't a thing in 365)

 - Set mail forward to manager for 30 days
 - After 15 days, send warning message to manager
 - After 30 days, reclaim assigned licenses
 - After 45 days, mark AD account for deletion (in description field)
 - After 60 days, delete the account
 - Report steps by email to helpdesk and former manager throughout the process

Extras:
  - Reclaim GoCanvas license (as necessary)
  - Reclaim Barracuda license
  - Remove user from GAL
  - Send message to wireless plan manager


  Blowing out this script in, virtually, it's entirety. 
#>


<#
# Set parameters.
param (
  [Parameter(Mandatory=$True)]
  [string]$Username,
  [Parameter(Mandatory=$False)]
  $Preserve=$False
)

<# Functions in the script.DESCRIPTION
Function Send-EmailMessage () {
  param (
    [Parameter(Mandatory=$False)]
    [string]$Recipients="helpdesk@nacgroup.com",
    [Parameter(Mandatory=$False)]
    [string]$ReportTitle,
    [Parameter(Mandatory=$False)]
    [string]$HTMLContent
  )

  #region Variables and Arguments
  $fromemail = "noyes-information@nacgroup.com"
  $server = "smtp.office365.com" #enter your own SMTP server DNS name / IP address here

  #Internal settings for email.
  $SourceMailbox = "noyes-information@nacgroup.com"
  $ReceiveMailbox = "$UserManagerEmail"
  $SourceMailboxPasswordSecure = ".\001Ref-SecureString.txt"
  $Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SourceMailbox,(Get-Content $SourceMailboxPasswordSecure | ConvertTo-SecureString)
  $ReportTitle = "User account terminated ($UserName)"

  #endregion

  # Assemble the HTML Header and CSS for our Report
  $HTMLHeader = @"
  <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
  <html><head><title>$ReportTitle</title>
  <style type="text/css">
  <!--
  body {
  font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
  }

      #report { width: 835px; }

      table{
  	border-collapse: collapse;
  	border: none;
  	font: 10pt Verdana, Geneva, Arial, Helvetica, sans-serif;
  	color: black;
  	margin-bottom: 10px;
  }

      table td{
  	font-size: 12px;
  	padding-left: 0px;
  	padding-right: 20px;
  	text-align: left;
  }

      table th {
  	font-size: 12px;
  	font-weight: bold;
  	padding-left: 0px;
  	padding-right: 20px;
  	text-align: left;
  }

  h2{ clear: both; font-size: 130%; }

  h3{
  	clear: both;
  	font-size: 115%;
  	margin-left: 20px;
  	margin-top: 30px;
  }

  p{ margin-left: 20px; font-size: 12px; }

  table.list{ float: left; }

      table.list td:nth-child(1){
  	font-weight: bold;
  	border-right: 1px grey solid;
  	text-align: right;
  }

  table.list td:nth-child(2){ padding-left: 7px; }
  table tr:nth-child(even) td:nth-child(even){ background: #CCCCCC; }
  table tr:nth-child(odd) td:nth-child(odd){ background: #F2F2F2; }
  table tr:nth-child(even) td:nth-child(odd){ background: #DDDDDD; }
  table tr:nth-child(odd) td:nth-child(even){ background: #E5E5E5; }
  div.column { width: 320px; float: left; }
  div.first{ padding-right: 20px; border-right: 1px  grey solid; }
  div.second{ margin-left: 30px; }
  table{ margin-left: 20px; }
  -->
  </style>
  </head>
  <body>

  @

  # Create HTML body for the report.
  $HTMLMiddle = "The password for $UserName was reset to $PlainPassword. Please log into the user mailbox (https://outlook.office.com) and OneDrive to identify any data that needs immediate attention. Mail will be forwarded to you for 30 days. After 30 days, the account will be marked for deletion. After 60 days, the account will be deleted."

  # Assemble the closing HTML for our report.
  $HTMLEnd = @
  </div>
  </body>
  </html>
  @

  # Assemble the final report from all our HTML sections
  $HTMLmessage = $HTMLHeader + $HTMLContent + $HTMLMiddle + $HTMLEnd
  # Save the report out to a file in the current path
  $HTMLmessage | Out-File ((Get-Location).Path + "\report.html")
  # Email our report out
  Send-MailMessage -To $ReceiveMailbox,$Recipients -Subject "[Report] $ReportTitle" -BodyAsHTML -Body $HTMLmessage -Attachments $ListOfAttachments -UseSsl -Port 587 -SmtpServer smtp.office365.com -From $SourceMailbox -Credential $Creds
}
#>



$Global:Password = $Null
$Global:Username = $Null
$Global:UPN = $Null

#Rebuilt the Generate Password Function to just fix a couple issues. 
#Function to Connect to O365
function Connect-Office365 {

Write-Host "Connect to 365. You'll provide your credentials twice"

# Pull credentials before moving to Office 365.
$MsolCredential = Get-Credential

#Connect to cloud services
# Sourced from https://docs.microsoft.com/en-us/powershell/azure/active-directory/enabling-licenses-sample?view=azureadps-2.0 on 11 Jan 2019.
Connect-MsolService -Credential $MsolCredential
Connect-AzureAD -Credential $MsolCredential
Connect-SPOService -Url https://nacgroup-admin.sharepoint.com -Credential $MsolCredential


$Session = New-PsSession -configurationname Microsoft.Exchange -Connectionuri https://ps.outlook.com/powershell-liveid?PSVersion=4.0/ -credential $MsolCredential -Authentication Basic -AllowRedirection
Import-PSSession $Session

Write-Host "Connected..."

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

Function Get-Username(){

Write-Host "Welcome to the NAC User Removal Script. We only need a little info to start the process."
$Username = Read-Host "Please Enter the Username of the user without the @nacgroup.com part"

$UPN = "$Username + '@nacgroup.com'"

}

Function Set-UserPassAndEmailToManager(){
<#
Function is to gather manager information, set the password of the user, and then notify the manager. In addition, it needs to write the password to a password protected file on the network drive. Ideally an excel spreadsheet

The excel spreadsheet must include
    Username
    Email
    Password
    Date the Deletion was requested
    Date the deletion will take full effect
#>
[string]$Manager = Get-ADUser -identity $username | select Manager
Set-ADAccountPassword -Identity $Username -Reset

$smtpCred = (Get-Credential)
$ToAddress = "jlunsford@nacgroup.com, $Manager"
$FromAddress = "nexus-admin@nacgroup.com"
$SmtpServer = "smtp.office365.com"
$SmtpPort = "587"

$mailparam = @{
    To = $ToAddress
    From = $FromAddress
    Subject = "User Password Reset"
    Body = "A password reset has been done for $UPN as part of the automated user removal process. If this was made in error please contact Jeremy Lunsford at jlunsford@nacgroup.com. You may view the new password at the standard location"
    SmtpServer = $smtpServer
    Port = $SmtpPort
    Credential = $smtpCred 
    
    }

Send-MailMessage @mailparam -UseSsl

}

Function Disable-MailLogon {

#disable the logon

set-msoluser -ObjectId $UPN -BlockCredential $true

}

function ObtainAndRemove-Groups {

#set the type of groups to be searched.
$GroupTypes = @("GroupMailbox","MailUniversalDistributionGroup","MailUniversalSecurityGroup")

#get a list of groups the user is in.
$Groups = Invoke-Command -Session $session -ScriptBlock { Get-Recipient -Filter "Members -eq '$($using:UPN)'" -RecipientTypeDetails $Using:GroupTypes | Select-Object DisplayName,ExternalDirectoryObjectId,RecipientTypeDetails } -ErrorAction SilentlyContinue -HideComputerName

#cycle through the retrieved groups

forEach($Group in $Groups) {
       #Alert the user that the identified user in the array is being removed.
       Write-Verbose "Removing user $UPN from group ""$($Group.DisplayName)"""
       Remove-UnifiedGroupLinks -Identity $Groups -Links $UPN -LinkType Members -Confirm $false
       #Provide a notification each removal confirming that the user was removed from the group
       Write-Verbose "$UPN was removed."
       }

#Remove the Sharepoint Access
Remove-SPOUserProfile -LoginName $UPN

}

function Hold-Mailbox { 

#Connect to the Security and Compliance Center

$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.compliance.protection.outlook.com/powershell-liveid -Credential $MsolCredential -Authentication Basic -AllowRedirection

New-MailboxSearch -Name "$UPN" + "Archive" -SourceMailboxes $upn -InPlaceHoldEnabled $true
Write-Host "The user $upn has been placed on an In-Place hold. Please allow up to 30 minutes for the hold to complete and then you may export it manually" `
"In order to accomplish the export refer to: https://docs.microsoft.com/en-us/exchange/policy-and-compliance/ediscovery/export-results-to-pst?view=exchserver-2019"

#as of yet i don't have a good way to capture their entire onedrive. The cmdlets for sharepoint are lacking. Either way I can't export it. However by default the manager of the user get's access following deletion of the user.







}



Connect-Office365

Get-Username

Generate-Password

Hold-Mailbox


<#
# Reset user password to random value. First create a random password.
# Taken from https://blogs.technet.microsoft.com/heyscriptingguy/2013/06/03/generating-a-new-password-with-windows-powershell/
$SourceData = $NULL; For ($a = 48; $a â€“le 122; $a++) { $SourceData+=, [char][byte]$a }
$PlainPassword = Get-Password -Length 12 -SourceData $SourceData
# Convert password to secure string.
$SecurePassword = ConvertTo-SecureString $PlainPassword -AsPlainText -Force
# Set user password to the returned password.
Set-ADAccountPassword -Identity $UserName -NewPassword $SecurePassword

# Get the Office 365 credentials for the administrator that is deleting the user.
$Admin365Credentials = Get-Credential
# Insert read-host
# Connect to Microsoft cloud resources.
Connect-MsolService -Credential $Admin365Credentials
Connect-AzureAD -Credential $Admin365Credentials
# $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Admin365Credentials -Authentication Basic -AllowRedirection
# Import-PSSession $Session -DisableNameChecking
Connect-SPOService -Url https://nacgroup-admin.sharepoint.com -Credential $Admin365Credentials

# Pull $Username and associated properties.
$UserProperties = Get-ADUser -Identity $UserName -Properties *
# Get manager.
$UserManager = $UserProperties.Manager
$UserManagerEmail = Get-ADUser -Identity $UserManager | Select-Object -ExpandProperty UserPrincipalName
# Get home folder.
$UserHomeDirectory = $UserProperties.HomeDirectory
# Get group membership.
$UserGroups = $UserProperties.MemberOf
# Get email.
$UserEmail = $UserProperties.UserPrincipalName

## Start actions.
# Remove user from local AD groups.
Foreach ( $Group in $UserGroups ) {
  Remove-ADGroupMember -Identity $Group -Members $UserName
}
# Move to Office 365 and remove user from groups.

# Remove user from GAL.
# There is no Connect-ExchangeOnline cmdlt at this point and no method of
# opening a nested PSSession per below. Removal from GAL is manual at this point.
# Enter-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Admin365Credentials -Authentication Basic -AllowRedirection
# Forward email messages to user's manager.

# Remove from SharePoint sites.
Remove-SPOUser -LoginName $UserEmail -Site https://nacgroup.sharepoint.com
# Send messages to third-party wireless manager and help desk for tracking.



## Follow up actions.
# After 15 days, send a warning message to user's manager to review before deletion date.
# Send-EmailMessage

# After 30 days, remove Office 365 license.
# User first needs to be assigned a region, then a license.
Set-MsolUserLicense -UserPrincipalName $UserEmail -RemoveLicenses "nacgroup:O365_BUSINESS_PREMIUM"
# After 45 days, mark account for deletion in local AD.

# After 60 days, delete the account.

## Reporting.
# Send pertinent information to help desk and user manager.


#>

<#

#create the excel file and make it visible to the rest of the users

$excel = New-Object -ComObject excel.application
$excel.visible = $True

$workbook = $excel.workbooks.add()

#add the worksheet and then give the worksheet a title

$usrremwrksht = $workbook.worksheets.Item(1)
$usrremwrksht.name = 'User Removal History'


#>


out-excel



<# 
Could be used for the capturing of the onedrive site

Import-Module Microsoft.Online.SharePoint.Powershell
$Output = "c:\source\Onedrive-Output.csv"
#Specify tenant admin and URL
$cred = Get-Credential
$TenantURL = "https://-admin.sharepoint.com"
$pattern = '[^a-zA-Z]'
#Configure Site URL and User
$SiteURL = "https://-my.sharepoint.com"
Connect-SPOService -Url "https://-admin.sharepoint.com" -Credential $cred

#Add references to SharePoint client assemblies and authenticate to Office 365 site - required for CSOM
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.dll"
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.UserProfiles.dll"
$Creds = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($cred.UserName,$cred.Password)

#Bind to Site Collection
$Context = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)
$Context.Credentials = $Creds

#Identify users in the Site Collection
$Users = $Context.Web.SiteUsers
$Context.Load($Users)
$Context.ExecuteQuery()

$PeopleManager = New-Object Microsoft.SharePoint.Client.UserProfiles.PeopleManager($Context)

$Headings = "Name","StorageUsed MB, Count"
$Headings -join "," | Out-File -Encoding default -FilePath $Output
Foreach ($User in $Users)
{
	$UserProfile = $PeopleManager.GetPropertiesFor($User.LoginName)
	$Context.Load($UserProfile)
	$Context.ExecuteQuery()
    
	If ($UserProfile.Email -ne $null)
    {
		$UPP = $UserProfile.UserProfileProperties
		try{
			if($UserProfile.PersonalUrl.Contains('PersonImmersive')){
			#this user probably does not have a mysite, but recreate url to check just incase
				$user = $UserProfile.Email -replace $pattern,'_'
				$url = "https://-my.sharepoint.com/personal"+$user
			}
			else{
				$url = $UserProfile.PersonalUrl.TrimEnd('/')
			}
			$site = Get-SPOSite -Identity $url
			$Properties = $UserProfile.DisplayName,$site.StorageUsageCurrent
		}
		catch [Exception]{
			$Properties = $UserProfile.DisplayName,"No mysite exists at $url"
		}

	    $Properties -join "," | Out-File -Encoding default -Append -FilePath $Output
    }  
}
#>