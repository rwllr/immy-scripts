$GroupName = "Domain Admins"
$ComputerList =Get-ComputersForADUserGroup($GroupName)
$Computer = Get-ImmyComputer

if ($Computer.Name -in $ComputerList.Name) {return $true}
else { return $false}
