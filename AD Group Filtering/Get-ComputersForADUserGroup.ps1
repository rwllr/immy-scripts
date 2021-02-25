	
param(
     [Parameter(Mandatory)]
     [ValidateSet('LoggedIn','Primary','Both')]
     [string]$UserType,
     
     [string]$GroupName
)
 
 # Get the first online Domain Controller
 $FirstDC = Get-ImmyComputer -TargetGroupFilter DomainControllers
 $FirstDC = $FirstDC | Select -First 1 
 
 
$GroupUsers = Invoke-ImmyCommand -Computer $FirstDC  {
  $Users = Get-ADGroupMember $using:GroupName -Recursive | % {get-aduser $_.SamAccountName }
  return $Users 
 }

$Devices = Get-ImmyComputer -TargetGroupFilter All -IncludeOffline -InventoryKeys LoggedOnUser

switch($UserType)
{
    "LoggedIn" {
      $Devices | Where { $GroupUsers.userPrincipalName -contains $_.Inventory.LoggedOnUser }
    }
    "Primary" {
      $Devices | Where { $GroupUsers.userPrincipalName -contains $_.PrimaryPersonEmail }
    }
    "Primary" {
      $Devices | Where { ($GroupUsers.userPrincipalName -contains $_.Inventory.LoggedOnUser) -or ($GroupUsers.userPrincipalName -contains $_.PrimaryPersonEmail) }
    }
}
