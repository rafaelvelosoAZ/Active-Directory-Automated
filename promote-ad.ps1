[CmdletBinding()]
param
(
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$Domain_DNSName,
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$SafeModeAdministratorPassword,
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$admin_username_domain,
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$admin_passwd
)

$SMAP = ConvertTo-SecureString -AsPlainText $SafeModeAdministratorPassword -Force
$Username = $admin_username_domain
$Password = ConvertTo-SecureString -AsPlainText $admin_passwd -Force

$DomainAdminCredential = New-Object -TypeName PSCredential -ArgumentList $Username, $Password
Install-windowsfeature -name AD-Domain-Services -IncludeManagementTools
Install-ADDSDomainController `
    -DomainName $Domain_DNSName `
    -Force:$true `
    -SkipPreChecks `
    -NoRebootOnCompletion:$false `
    -Credential $DomainAdminCredential `
    -SafeModeAdministratorPassword $SMAP