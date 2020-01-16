connect-azureAD

$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile

$PasswordProfile.Password = "Password"

New-AzureADUser -DisplayName "Test User" -PasswordProfile $PasswordProfile -UserPrincipalName "testuser@contoso.com" -AccountEnabled $true -MailNickName "testuser"