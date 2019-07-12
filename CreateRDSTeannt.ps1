# Don't change the deploymenturl
Add-RdsAccount -DeploymentUrl "https://rdbroker.wvd.microsoft.com"
# Use any name for your tenant, get your ID from Azure portal > Azure Active Directory > Properties > Directory ID. To get your SubscriptionID, go to Azure Portal > All services > subscriptions > click the subscription where the VM's will reside and copy the subscription ID:
New-RdsTenant -Name "NexusCloudITWVD" -AadTenantId "238da48c-8c54-4e24-9f6d-923ba133827b" -AzureSubscriptionId "e2276d4a-5441-4dc2-b8c5-ef34364a24c2"

$myTenantGroupName = "Default Tenant Group"
$myTenantName = "NexusCloudITWVD" #As you used in the previous step
$hostpoolname = "NexCloudHostPool"

# create the service principal:
$aadContext = Connect-AzureAD
$svcPrincipal = New-AzureADApplication -AvailableToOtherTenants $true -DisplayName "Windows Virtual Desktop Svc Principal"
$svcPrincipalCreds = New-AzureADApplicationPasswordCredential -ObjectId $svcPrincipal.ObjectId

# Don't change the URL below.
Add-RdsAccount -DeploymentUrl "https://rdbroker.wvd.microsoft.com" 
Set-RdsContext -TenantGroupName $myTenantGroupName
New-RdsHostPool -TenantName $myTenantName -name $hostpoolname

New-RdsRoleAssignment -RoleDefinitionName "RDS Owner" -ApplicationId $svcPrincipal.AppId -TenantGroupName $myTenantGroupName -TenantName $myTenantName -HostPoolName $hostpoolname