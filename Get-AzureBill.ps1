<# 
Script to get the latest azure AD bill

Joshua K Raup
#>


#Gather Credentials
$MsolCredential = Get-Credential

#Connect to the necessary services and then import/install the necessary modules 
Connect-AzureAD -Credential $MsolCredential
install-module AzureRM

#Connect to the AzureRMAccount
Connect-AzureRmAccount -Credential $msolcredential

#create new pssession and then import it.
$Session = New-PsSession -configurationname Microsoft.Exchange -Connectionuri https://ps.outlook.com/powershell-liveid?PSVersion=4.0/ -credential $MsolCredential -Authentication Basic -AllowRedirection
Import-PSSession $Session

#run the azure invoice retrieval for the latest billing cycle. 
get-azurermbillinginvoice -latest

