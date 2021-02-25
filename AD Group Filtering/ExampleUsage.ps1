$GroupName = "Domain Admins" 
$ComputerList =Get-ComputersForADUserGroup -UserType "LoggedIn" -GroupName $GroupName
$Computer = Get-ImmyComputer

if ($Computer.Name -in $ComputerList.Name) {return $true}
else { return $false}
