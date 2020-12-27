###################### Maintenance Task Setup ######################
#+--------+-----------+---------------------------+--------------------+----------+
#| Name   | Data Type | Default Value             | Notes              | Required |
#+--------+-----------+---------------------------+--------------------+----------+
#| APIKEy | Password  |                           | ITGlue APIKey      | Yes      |
#+--------+-----------+---------------------------+--------------------+----------+
#| APIURL | Text      | https://api.eu.itglue.com | URL for ITGlue API |          |
#+--------+-----------+---------------------------+--------------------+----------+
#|        |           |                           |                    |          |
#+--------+-----------+---------------------------+--------------------+----------+

###################### Script Setup ######################
#+-------------------+------------------+
#| Name              | Value            |
#+-------------------+------------------+
#| Access Level      | All              |
#+-------------------+------------------+
#| Type              | Maintenance Task |
#+-------------------+------------------+
#| Hidden            | No               |
#+-------------------+------------------+
#| Action Type       | PowerShell       |
#+-------------------+------------------+
#| Timeout           | Default          |
#+-------------------+------------------+
#| Execution Context | Metascript       |
#+-------------------+------------------+

# Below module is flattened ITGlue module
# https://github.com/itglue/powershellwrapper

Set-Variable -Name "ITGlue_Headers" -Value @{} -Scope global -Force
Set-Variable -Name "ITGlue_JSON_Conversion_Depth" -Value 100 -Scope global -Force
$ITGlue_Headers.Add("Content-Type", 'application/vnd.api+json') 

function Add-ITGlueAPIKey {
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [Alias('ApiKey')]
        [string]$Api_Key
    )
    #Set-Variable -Name "ITGlue_Headers" -Value @{} -Scope global -Force
    if ($Api_Key) {
        $x_api_key = ConvertTo-SecureString $Api_Key -AsPlainText -Force
        Set-Variable -Name "ITGlue_API_Key" -Value $x_api_key -Option ReadOnly -Scope global -Force
    }
    else {
        Write-Host "Please enter your API key:"
        $x_api_key = Read-Host -AsSecureString
        Set-Variable -Name "ITGlue_API_Key" -Value $x_api_key -Option ReadOnly -Scope global -Force
    }
}

function Remove-ITGlueAPIKey {
    Remove-Variable -Name "ITGlue_API_Key" -Scope global -Force
}

function Get-ITGlueAPIKey {
    if($null -eq $ITGlue_API_Key) {
        Write-Error "No API key exists. Please run Add-ITGlueAPIKey to add one."
    }
    else {
        $ITGlue_API_Key
    }
}

New-Alias -Name Set-ITGlueAPIKey -Value Add-ITGlueAPIKey
function Add-ITGlueBaseURI {
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipeline)]
        [string]$base_uri = 'https://api.itglue.com',

        [Alias('locale','dc')]
        [ValidateSet( 'US', 'EU')]
        [String]$data_center = ''
    )

    # Trim superflous forward slash from address (if applicable)
    if($base_uri[$base_uri.Length-1] -eq "/") {
        $base_uri = $base_uri.Substring(0,$base_uri.Length-1)
    }

    switch ($data_center) {
        'US' {$base_uri = 'https://api.itglue.com'}
        'EU' {$base_uri = 'https://api.eu.itglue.com'}
        Default {}
    }

    Set-Variable -Name "ITGlue_Base_URI" -Value $base_uri -Option ReadOnly -Scope global -Force
}

function Remove-ITGlueBaseURI {
    Remove-Variable -Name "ITGlue_Base_URI" -Scope global -Force 
}

function Get-ITGlueBaseURI {
    $ITGlue_Base_URI
}

New-Alias -Name Set-ITGlueBaseURI -Value Add-ITGlueBaseURI
# Locations of settings path and file
$ITGlueAPIConfPath = "$($env:USERPROFILE)\ITGlueAPI"
$ITGlueAPIConfFile = "config.psd1"

function Export-ITGlueModuleSettings {
    # Confirm variables exist and are not null before exporting
    if ($ITGlue_Base_URI -and $ITGlue_API_Key -and $ITGlue_JSON_Conversion_Depth) {
        $secureString = $ITGlue_API_KEY | ConvertFrom-SecureString
        New-Item -ItemType Directory -Force -Path $ITGlueAPIConfPath | ForEach-Object{$_.Attributes = "hidden"}
@"
@{
    ITGlue_Base_URI = '$ITGlue_Base_URI'
    ITGlue_API_Key = '$secureString'
    ITGlue_JSON_Conversion_Depth = '$ITGlue_JSON_Conversion_Depth'
}
"@ | Out-File -FilePath ($ITGlueAPIConfPath+"\"+$ITGlueAPIConfFile) -Force
    }
    else {
        Write-Host "Failed export ITGlue Module settings to $ITGlueAPIConfPath\$ITGlueAPIConfFile"
    }
}

function Import-ITGlueModuleSettings {

    # PLEASE ADD ERROR CHECKING SUCH AS TESTING FOR VALID VARIABLES?

    if(test-path ($ITGlueAPIConfPath+"\"+$ITGlueAPIConfFile) )  {
        $tmp_config = Import-LocalizedData -BaseDirectory $ITGlueAPIConfPath -FileName $ITGlueAPIConfFile

        # Send to function to strip potentially superflous slash (/)
        Add-ITGlueBaseURI $tmp_config.ITGlue_Base_URI

        $tmp_config.ITGlue_API_key = ConvertTo-SecureString $tmp_config.ITGlue_API_key

        Set-Variable -Name "ITGlue_API_Key"  -Value $tmp_config.ITGlue_API_key `
                    -Option ReadOnly -Scope global -Force

        Set-Variable -Name "ITGlue_JSON_Conversion_Depth" -Value $tmp_config.ITGlue_JSON_Conversion_Depth `
                    -Scope global -Force 

        Write-Host "ITGlueAPI Module configuration loaded successfully from $ITGlueAPIConfPath\$ITGlueAPIConfFile!" -ForegroundColor Green

        # Clean things up
        Remove-Variable "tmp_config"
    }
    else {
        Write-Host "No configuration file was found at $ITGlueAPIConfPath\$ITGlueAPIConfFile." -ForegroundColor Red
        
        Set-Variable -Name "ITGlue_Base_URI" -Value "https://api.itglue.com" -Option ReadOnly -Scope global -Force
        
        Write-Host "Using https://api.itglue.com as Base URI. Run Add-ITGlueBaseURI to modify."
        Write-Host "Please run Add-ITGlueAPIKey to get started." -ForegroundColor Red
        
        Set-Variable -Name "ITGlue_JSON_Conversion_Depth" -Value 100 -Scope global -Force
    }
}

function New-ITGlueConfigurationInterfaces {
    Param (
        [Nullable[Int64]]$conf_id = $null,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/configuration_interfaces/'

    if ($conf_id) {
        $resource_uri = ('/configurations/{0}/relationships/configuration_interfaces' -f $conf_id)
    }

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGlueConfigurationInterfaces {
    [CmdletBinding(DefaultParametersetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$conf_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet('created_at', 'updated-at', `
                '-created_at', '-updated-at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/configurations/{0}/relationships/configuration_interfaces/{1}' -f $conf_id, $id)
    if (($PsCmdlet.ParameterSetName -eq 'show') -and ($null -eq $conf_id)) {
        $resource_uri = ('/configuration_interfaces/{0}' -f $id)
    }

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGlueConfigurationInterfaces {
    [CmdletBinding(DefaultParametersetName = 'update')]
    Param (
        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$id,

        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$conf_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'update')]
        [Parameter(ParameterSetName = 'bulk_update')]
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/configuration_interfaces/{0}' -f $id)

    if ($conf_id) {
        $resource_uri = ('/configurations/{0}/relationships/configuration_interfaces/{1}' -f $conf_id, $id)
    }

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'bulk_delete') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
    }

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function New-ITGlueConfigurations {
    Param (
        [Nullable[Int64]]$organization_id = $null,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/configurations'

    if ($organization_id) {
        $resource_uri = ('/organizations/{0}/relationships/configurations' -f $organization_id)
    }

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGlueConfigurations {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id,

        [Parameter(ParameterSetName = 'index')]
        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$organization_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_id = '',

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_organization_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_configuration_type_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_configuration_status_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_contact_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_serial_number = '',

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_rmm_id = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet('addigy', 'aem', 'atera', 'managed-workplace', `
                'continuum', 'jamf-pro', 'kaseya-vsa', 'automate', `
                'msp-rmm', 'msp-n-central', 'ninja-rmm', 'panorama9', `
                'pulseway-rmm', 'watchman-monitoring')]
        [String]$filter_rmm_integration_type = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet('name', 'id', 'created_at', 'updated-at', `
                '-name', '-id', '-created_at', '-updated-at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'index')]
        [Parameter(ParameterSetName = 'show')]
        [String]$include = ''
    )

    if($organization_id) {
        #Switch to nested relationships route
        $resource_uri = ('/organizations/{0}/relationships/configurations/{1}' -f $organization_id, $id)
    }
    else {
        $resource_uri = ('/configurations/{0}' -f $id)
    }

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($filter_organization_id) {
            $body += @{'filter[organization_id]' = $filter_organization_id}
        }
        if ($filter_configuration_type_id) {
            $body += @{'filter[configuration_type_id]' = $filter_configuration_type_id}
        }
        if ($filter_configuration_status_id) {
            $body += @{'filter[configuration_status_id]' = $filter_configuration_status_id}
        }
        if ($filter_contact_id) {
            $body += @{'filter[contact_id]' = $filter_contact_id}
        }
        if ($filter_serial_number) {
            $body += @{'filter[serial_number]' = $filter_serial_number}
        }
        if ($filter_rmm_id) {
            $body += @{'filter[rmm_id]' = $filter_rmm_id}
        }
        if ($filter_rmm_integration_type) {
            $body += @{'filter[rmm_integration_type]' = $filter_rmm_integration_type}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    if($include) {
        $body += @{'include' = $include}
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers -body $body
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }


    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGlueConfigurations {
    [CmdletBinding(DefaultParameterSetName = 'update')]
    Param (
        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$id = $null,

        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$organization_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_organization_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_configuration_type_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_configuration_status_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_contact_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [String]$filter_serial_number = '',

        [Parameter(ParameterSetName = 'bulk_update')]
        [String]$filter_rmm_id = '',

        [Parameter(ParameterSetName = 'bulk_update')]
        [ValidateSet('addigy', 'aem', 'atera', 'managed-workplace', `
                'continuum', 'jamf-pro', 'kaseya-vsa', 'automate', `
                'msp-rmm', 'msp-n-central', 'ninja-rmm', 'panorama9', `
                'pulseway-rmm', 'watchman-monitoring')]
        [String]$filter_rmm_integration_type = '',

        [Parameter(ParameterSetName = 'update')]
        [Parameter(ParameterSetName = 'bulk_update')]
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/configurations/{0}' -f $id)

    if ($flexible_asset_type_id) {
        $resource_uri = ('/organizations/{0}/relationships/configurations/{1}' -f $organization_id, $id)
    }

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'bulk_update') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($filter_organization_id) {
            $body += @{'filter[organization_id]' = $filter_organization_id}
        }
        if ($filter_configuration_type_id) {
            $body += @{'filter[configuration_type_id]' = $filter_configuration_type_id}
        }
        if ($filter_configuration_status_id) {
            $body += @{'filter[configuration_status_id]' = $filter_configuration_status_id}
        }
        if ($filter_contact_id) {
            $body += @{'filter[contact_id]' = $filter_contact_id}
        }
        if ($filter_serial_number) {
            $body += @{'filter[serial_number]' = $filter_serial_number}
        }
        if ($filter_rmm_id) {
            $body += @{'filter[rmm_id]' = $filter_rmm_id}
        }
        if ($filter_rmm_integration_type) {
            $body += @{'filter[rmm_integration_type]' = $filter_rmm_integration_type}
        }
    }

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Remove-ITGlueConfigurations {
    [CmdletBinding(DefaultParameterSetName = 'bulk_delete')]
    Param (
        [Parameter(ParameterSetName = 'bulk_delete')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'bulk_delete')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'bulk_delete')]
        [Nullable[Int64]]$filter_organization_id = $null,

        [Parameter(ParameterSetName = 'bulk_delete')]
        [Nullable[Int64]]$filter_configuration_type_id = $null,

        [Parameter(ParameterSetName = 'bulk_delete')]
        [Nullable[Int64]]$filter_configuration_status_id = $null,

        [Parameter(ParameterSetName = 'bulk_delete')]
        [Nullable[Int64]]$filter_contact_id = $null,

        [Parameter(ParameterSetName = 'bulk_delete')]
        [String]$filter_serial_number = '',

        [Parameter(ParameterSetName = 'bulk_delete')]
        [String]$filter_rmm_id = '',

        [Parameter(ParameterSetName = 'bulk_delete')]
        [ValidateSet('addigy', 'aem', 'atera', 'managed-workplace', `
                'continuum', 'jamf-pro', 'kaseya-vsa', 'automate', `
                'msp-rmm', 'msp-n-central', 'ninja-rmm', 'panorama9', `
                'pulseway-rmm', 'watchman-monitoring')]
        [String]$filter_rmm_integration_type = '',

        [Parameter(ParameterSetName = 'bulk_delete')]
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/configurations/'

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'bulk_delete') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($filter_organization_id) {
            $body += @{'filter[organization_id]' = $filter_organization_id}
        }
        if ($filter_configuration_type_id) {
            $body += @{'filter[configuration_type_id]' = $filter_configuration_type_id}
        }
        if ($filter_configuration_status_id) {
            $body += @{'filter[configuration_status_id]' = $filter_configuration_status_id}
        }
        if ($filter_contact_id) {
            $body += @{'filter[contact_id]' = $filter_contact_id}
        }
        if ($filter_serial_number) {
            $body += @{'filter[serial_number]' = $filter_serial_number}
        }
        if ($filter_rmm_id) {
            $body += @{'filter[rmm_id]' = $filter_rmm_id}
        }
        if ($filter_rmm_integration_type) {
            $body += @{'filter[rmm_integration_type]' = $filter_rmm_integration_type}
        }
    }

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'DELETE' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function New-ITGlueConfigurationStatuses {
    Param (
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/configuration_statuses/'

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
    $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
        -body $body -ErrorAction Stop -ErrorVariable $web_error
    [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGlueConfigurationStatuses {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'id', 'created_at', 'updated_at', `
                '-name', '-id', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/configuration_statuses/{0}' -f $id)

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
    $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
        -body $body -ErrorAction Stop -ErrorVariable $web_error
    [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGlueConfigurationStatuses {
    Param (
        [Parameter(Mandatory = $true)]
        [Int64]$id,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/configuration_statuses/{0}' -f $id)

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
    $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
        -body $body -ErrorAction Stop -ErrorVariable $web_error
    [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist

    $data = @{}
    $data = $rest_output
    return $data
}
function New-ITGlueConfigurationTypes {
    Param (
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/configuration_types/'

    $body = @{}

    $body += @{'data'= $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGlueConfigurationTypes {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'id', 'created_at', 'updated_at', `
                '-name', '-id', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/configuration_types/{0}' -f $id)

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGlueConfigurationTypes {
    Param (
        [Parameter(Mandatory = $true)]
        [Int64]$id,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/configuration_types/{0}' -f $id)

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function New-ITGlueContacts {
    Param (
        [Nullable[Int64]]$organization_id = $null,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/contacts'

    if ($organization_id) {
        $resource_uri = ('/organizations/{0}/relationships/contacts' -f $organization_id)
    }

    $body = @{}

    $body += @{'data'= $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGlueContacts {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$organization_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_first_name = '',

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_last_name = '',

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_title = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_contact_type_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Boolean]]$filter_important = $null,

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_primary_email = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'first_name', 'last_name', 'id', 'created_at', 'updated_at', `
                '-first_name', '-last_name', '-id', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Parameter(ParameterSetName = 'show')]
        $include = ''
    )

    $resource_uri = ('/contacts/{0}' -f $id)
    if ($organization_id) {
        $resource_uri = ('/organizations/{0}/relationships' -f $organization_id) + $resource_uri
    }

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if ($filter_first_name) {
            $body += @{'filter[first_name]' = $filter_first_name}
        }
        if ($filter_last_name) {
            $body += @{'filter[last_name]' = $filter_last_name}
        }
        if ($filter_title) {
            $body += @{'filter[title]' = $filter_title}
        }
        if ($filter_contact_type_id) {
            $body += @{'filter[contact_type_id]' = $filter_contact_type_id}
        }
        if ($filter_important -eq $true) {
            $body += @{'filter[important]' = '1'}
        }
        elseif ($filter_important -eq $false) {
            $body += @{'filter[important]' = '0'}
        }
        if ($filter_primary_email) {
            $body += @{'filter[primary_email]' = $filter_primary_email}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    if($include) {
        $body += @{'include' = $include}
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    $data
    return $data
}

function Set-ITGlueContacts {
    [CmdletBinding(DefaultParameterSetName = 'update')]
    Param (
        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$id = $null,

        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$organization_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [String]$filter_first_name = '',

        [Parameter(ParameterSetName = 'bulk_update')]
        [String]$filter_last_name = '',

        [Parameter(ParameterSetName = 'bulk_update')]
        [String]$filter_title = '',

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_contact_type_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Boolean]]$filter_important = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [String]$filter_primary_email = '',

        [Parameter(ParameterSetName = 'update')]
        [Parameter(ParameterSetName = 'bulk_update')]
        [Parameter(Mandatory = $true)]
        $data

    )

    $resource_uri = ('/contacts/{0}' -f $id)

    if ($flexible_asset_type_id) {
        $resource_uri = ('/organizations/{0}/relationships/contacts/{1}' -f $organization_id, $id)
    }

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'bulk_update') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if ($filter_first_name) {
            $body += @{'filter[first_name]' = $filter_first_name}
        }
        if ($filter_last_name) {
            $body += @{'filter[last_name]' = $filter_last_name}
        }
        if ($filter_title) {
            $body += @{'filter[title]' = $filter_title}
        }
        if ($filter_contact_type_id) {
            $body += @{'filter[contact_type_id]' = $filter_contact_type_id}
        }
        if ($filter_important -eq $true) {
            $body += @{'filter[important]' = '1'}
        }
        elseif ($filter_import -eq $false) {
            $body += @{'filter[important]' = '0'}
        }
        if ($filter_primary_email) {
            $body += @{'filter[primary_email]' = $filter_primary_email}
        }
    }

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Remove-ITGlueContacts {
    [CmdletBinding(DefaultParameterSetName = 'bulk_destroy')]
    Param (
        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [String]$filter_first_name = '',

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [String]$filter_last_name = '',

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [String]$filter_title = '',

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_contact_type_id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Boolean]]$filter_important = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [String]$filter_primary_email = '',

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/contacts/{0}' -f $id)

    if ($flexible_asset_type_id) {
        $resource_uri = ('/organizations/{0}/relationships/contacts/{1}' -f $organization_id, $id)
    }

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'bulk_destroy') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if ($filter_first_name) {
            $body += @{'filter[first_name]' = $filter_first_name}
        }
        if ($filter_last_name) {
            $body += @{'filter[last_name]' = $filter_last_name}
        }
        if ($filter_title) {
            $body += @{'filter[title]' = $filter_title}
        }
        if ($filter_contact_type_id) {
            $body += @{'filter[contact_type_id]' = $filter_contact_type_id}
        }
        if ($filter_important -eq $true) {
            $body += @{'filter[important]' = '1'}
        }
        elseif ($filter_important -eq $false) {
            $body += @{'filter[important]' = '0'}
        }
        if ($filter_primary_email) {
            $body += @{'filter[primary_email]' = $filter_primary_email}
        }
    }

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'DELETE' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function New-ITGlueContactTypes {
    Param (
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/contact_types/'

    $body = @{}

    $body += @{'data'= $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGlueContactTypes {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'id', 'created_at', 'updated_at', `
                '-name', '-id', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/contact_types/{0}' -f $id)

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGlueContactTypes {
    Param (
        [Parameter(Mandatory = $true)]
        [Int64]$id,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/contact_types/{0}' -f $id)

    $body = @{}

    $body += @{'data'= $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function Get-ITGlueCountries {
    [CmdletBinding(DefaultParameterSetName = "index")]
    Param (
        [Parameter(ParameterSetName = "index")]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = "index")]
        [String]$filter_iso = '',

        [Parameter(ParameterSetName = "index")]
        [ValidateSet( 'name', 'id', 'created_at', 'updated_at', `
                '-name', '-id', '-created_at', '-updated_at')]
        [String]$sort = "",

        [Parameter(ParameterSetName = "index")]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = "index")]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = "show")]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/countries/{0}' -f $id)

    if ($PSCmdlet.ParameterSetName -eq "index") {
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($filter_iso) {
            $body += @{'filter[iso]' = $filter_iso}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{"page[number]" = $page_number}
        }
        if ($page_size) {
            $body += @{"page[size]" = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add("x-api-key", (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method "GET" -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function New-ITGlueFlexibleAssetFields {
    Param (
        [Nullable[Int64]]$flexible_asset_type_id = $null,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/flexible_asset_fields/'

    if ($flexible_asset_type_id) {
        $resource_uri = ('/flexible_asset_types/{0}/relationships/flexible_asset_fields' -f $flexible_asset_type_id)
    }

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGlueFlexibleAssetFields {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$flexible_asset_type_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'created_at', 'updated_at', `
                '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/flexible_asset_fields/{0}' -f $id)

    if ($flexible_asset_type_id) {
        $resource_uri = ('/flexible_asset_types/{0}/relationships/flexible_asset_fields/{1}' -f $flexible_asset_type_id, $id)
    }

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }
    elseif ($null -eq $flexible_asset_type_id) {
        #Parameter set "Show" is selected and no flexible asset type id is specified; switch from nested relationships route
        $resource_uri = ('/flexible_asset_fields/{0}' -f $id)
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGlueFlexibleAssetFields {
    [CmdletBinding(DefaultParameterSetName = 'update')]
    Param (
        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$flexible_asset_type_id = $null,

        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'update')]
        [Parameter(ParameterSetName = 'bulk_update')]
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/flexible_asset_fields/{0}' -f $id)

    if ($flexible_asset_type_id) {
        $resource_uri = ('/flexible_asset_types/{0}/relationships/flexible_asset_fields/{1}' -f $flexible_asset_type_id, $id)
    }

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'bulk_update') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
    }

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Remove-ITGlueFlexibleAssetFields {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param (
        [Parameter(Mandatory = $true)]
        [Int64]$id,

        [Nullable[Int64]]$flexible_asset_type_id = $null
    )

    $resource_uri = ('/flexible_asset_fields/{0}' -f $id)

    if ($flexible_asset_type_id) {
        $resource_uri = ('/flexible_asset_types/{0}/relationships/flexible_asset_fields/{1}' -f $flexible_asset_type_id, $id)
    }

    if ($pscmdlet.ShouldProcess($id)) {

        try {
            $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
            $rest_output = Invoke-RestMethod -method 'DELETE' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
                -ErrorAction Stop -ErrorVariable $web_error
        } catch {
            Write-Error $_
        } finally {
            [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
        }

        $data = @{}
        $data = $rest_output
        return $data
    }
}
function New-ITGlueFlexibleAssets {
    Param (
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/flexible_assets/'

    $body = @{}

    $body += @{'data'= $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGlueFlexibleAssets {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_flexible_asset_type_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_organization_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'created_at', 'updated_at', `
                '-name', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'index')]
        [Parameter(ParameterSetName = 'show')]
        [String]$include = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/flexible_assets/{0}' -f $id)

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_flexible_asset_type_id) {
            $body += @{'filter[flexible_asset_type_id]' = $filter_flexible_asset_type_id}
        }
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($filter_organization_id) {
            $body += @{'filter[organization_id]' = $filter_organization_id}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    if ($include) {
        $body += @{'include' = $include}
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        $ITGlue_Headers.Remove('x-api-key') >$null # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGlueFlexibleAssets {
    [CmdletBinding(DefaultParameterSetName = 'update')]
    Param (
        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$id = $null,

        [Parameter(ParameterSetName = 'update')]
        [Parameter(ParameterSetName = 'bulk_update')]
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/flexible_assets/{0}' -f $id)

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Remove-ITGlueFlexibleAssets {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param (
        [Parameter(Mandatory = $true)]
        [Int64]$id
    )

    $resource_uri = ('/flexible_assets/{0}' -f $id)

    if ($pscmdlet.ShouldProcess($id)) {

        try {
            $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
            $rest_output = Invoke-RestMethod -method 'DELETE' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
                -ErrorAction Stop -ErrorVariable $web_error
        } catch {
            Write-Error $_
        } finally {
            [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
        }

        $data = @{}
        $data = $rest_output
        return $data
    }
}
function New-ITGlueFlexibleAssetTypes {
    Param (
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/flexible_asset_types/'

    $body = @{}

    $body += @{'data'= $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function Get-ITGlueFlexibleAssetTypes {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_icon = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Boolean]]$filter_enabled = $null,

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'id', 'created_at', 'updated_at', `
                '-name', '-id', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'index')]
        [String]$include = '',

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/flexible_asset_types/{0}' -f $id)

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($filter_icon) {
            $body += @{'filter[icon]' = $filter_icon}
        }
        if ($filter_enabled -eq $true) {
            # PS $true returns "True" in string form (uppercase) and ITG's API is case-sensitive, so being explicit
            $body += @{'filter[enabled]' = "1"}
        }
        elseif ($filter_enabled -eq $false) {
            $body += @{'filter[enabled]' = "0"}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    if($include) {
        $body += @{'include' = $include}
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGlueFlexibleAssetTypes {
    Param (
        [Parameter(Mandatory = $true)]
        [Int64]$id,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/flexible_asset_types/{0}' -f $id)

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function Get-ITGlueGroups {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'created_at', 'updated_at', `
                '-name', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/groups/{0}' -f $id)

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function New-ITGlueLocations {
    Param (
        [Parameter(Mandatory = $true)]
        [Int64]$org_id,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/organizations/{0}/relationships/locations/' -f $org_id)

    $body = @{}

    $body += @{'data'= $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function Get-ITGlueLocations {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$org_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_id = '',

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_city = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_region_id = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_country_id = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'id', 'created_at', 'updated_at', `
                '-name', '-id', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int64]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Parameter(ParameterSetName = 'show')]
        [String]$include = ''
    )

    $resource_uri = ('/locations/{0}' -f $id)
    if ($org_id) {
        $resource_uri = ('/organizations/{0}/relationships' -f $org_id) + $resource_uri
    }

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($filter_city) {
            $body += @{'filter[city]' = $filter_city}
        }
        if ($filter_region_id) {
            $body += @{'filter[region_id]' = $filter_region_id}
        }
        if ($filter_country_id) {
            $body += @{'filter[country_id]' = $filter_country_id}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    if($include) {
        $body += @{'include' = $include}
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGlueLocations {
    [CmdletBinding(DefaultParameterSetName = 'update')]
    Param (
        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$id = $null,

        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$org_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'bulk_update')]
        [String]$filter_city = '',

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_region_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_country_id = $null,

        [Parameter(ParameterSetName = 'update')]
        [Parameter(ParameterSetName = 'bulk_update')]
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/locations/{0}' -f $id)

    if ($org_id) {
        $resource_uri = ('organizations/{0}/relationships/locations/{1}' -f $org_id, $id)
    }

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'bulk_update') {
        if($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if($filter_city) {
            $body += @{'filter[city]' = $filter_city}
        }
        if($filter_region_id) {
            $body += @{'filter[region_id]' = $filter_region_id}
        }
        if($filter_country_id) {
            $body += @{'filter[country_id]' = $filter_country_id}
        }
    }

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Remove-ITGlueLocations {
    [CmdletBinding(DefaultParameterSetName = 'bulk_destroy')]
    Param (
        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [String]$filter_city = '',

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_region_id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_country_id = $null,

        [Parameter(ParameterSetName = 'update')]
        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/locations/')

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'bulk_destroy') {
        if($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if($filter_city) {
            $body += @{'filter[city]' = $filter_city}
        }
        if($filter_region_id) {
            $body += @{'filter[region_id]' = $filter_region_id}
        }
        if($filter_country_id) {
            $body += @{'filter[country_id]' = $filter_country_id}
        }
    }

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'DELETE' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function New-ITGlueManufacturers {
    Param (
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/manufacturers/'

    $body = @{}

    $body += @{'data'= $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGlueManufacturers {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'id', 'created_at', 'updated_at', `
                '-name', '-id', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/manufacturers/{0}' -f $id)

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGlueManufacturers {
    Param (
        [Parameter(Mandatory = $true)]
        [Int64]$id,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/manufacturers/{0}' -f $id)

    $body = @{}

    $body += @{'data'= $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function New-ITGlueModels {
    Param (
        [Nullable[Int64]]$manufacturer_id = $null,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/models/'

    if ($manufacturer_id) {
        $resource_uri = ('/manufacturers/{0}/relationships/models' -f $manufacturer_id)
    }

    $body = @{}

    $body += @{'data'= $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGlueModels {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$manufacturer_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'id', 'name', 'manufacturer_id', 'created_at', 'updated_at', `
                '-id', '-name', '-manufacturer_id', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/models/{0}' -f $id)
    if ($manufacturer_id) {
        $resource_uri = ('/manufacturers/{0}/relationships' -f $manufacturer_id) + $resource_uri
    }

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGlueModels {
    [CmdletBinding(DefaultParameterSetName = 'update')]
    Param (
        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$id = $null,

        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$manufacturer_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'update')]
        [Parameter(ParameterSetName = 'bulk_update')]
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/models/{0}' -f $id)

    if ($manufacturer_id) {
        $resource_uri = ('/manufacturers/{0}/relationships/models/{1}' -f $manufacturer_id, $id)
    }

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'bulk_update') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
    }

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function Get-ITGlueOperatingSystems {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'id', 'created_at', 'updated_at', `
                '-name', '-id', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/operating_systems/{0}' -f $id)

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function New-ITGlueOrganizations {
    Param (
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/organizations/'

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGlueOrganizations {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_organization_type_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_organization_status_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_created_at = '',

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_updated_at = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_my_glue_account_id = $null,
        
        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_group_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_exclude_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_exclude_name = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_exclude_organization_type_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_exclude_organization_status_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_range = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_range_my_glue_account_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'id', 'updated_at', 'organization_status_name', 'organization_type_name', 'created_at', 'short_name', 'my_glue_account_id',`
                '-name', '-id', '-updated_at', '-organization_status_name', '-organization_type_name', '-created_at', '-short_name', '-my_glue_account_id')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/organizations/{0}' -f $id)

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($filter_organization_type_id) {
            $body += @{'filter[organization_type_id]' = $filter_organization_type_id}
        }
        if ($filter_organization_type_id) {
            $body += @{'filter[organization_status_id]' = $filter_organization_status_id}
        }
        if ($filter_created_at) {
            $body += @{'filter[created_at]' = $filter_created_at}
        }
        if ($filter_updated_at) {
            $body += @{'filter[updated_at]' = $filter_updated_at}
        }
        if ($filter_my_glue_account_id) {
            $body += @{'filter[my_glue_account_id]' = $filter_my_glue_account_id}
        }
        if ($filter_group_id) {
            $body += @{'filter[group_id]' = $filter_group_id}
        }
        if ($filter_exclude_id) {
            $body += @{'filter[exclude][id]' = $filter_exclude_id}
        }
        if ($filter_exclude_name) {
            $body += @{'filter[exclude][name]' = $filter_exclude_name}
        }
        if ($filter_exclude_organization_type_id) {
            $body += @{'filter[exclude][organization_type_id]' = $filter_exclude_organization_type_id}
        }
        if ($filter_exclude_organization_type_id) {
            $body += @{'filter[exclude][organization_status_id]' = $filter_exclude_organization_status_id}
        }
        if ($filter_range) {
            $body += @{'filter[range]' = $filter_range}
        }
        if ($filter_range_my_glue_account_id) {
            $body += @{'filter[range][my_glue_account_id]' = $filter_range_my_glue_account_id}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGlueOrganizations {
    [CmdletBinding(DefaultParameterSetName = 'update')]
    Param (
        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_organization_type_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_organization_status_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [String]$filter_created_at = '',

        [Parameter(ParameterSetName = 'bulk_update')]
        [String]$filter_updated_at = '',

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_my_glue_account_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_exclude_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [String]$filter_exclude_name = '',

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_exclude_organization_type_id = $null,

        [Parameter(ParameterSetName = 'bulk_update')]
        [Nullable[Int64]]$filter_exclude_organization_status_id = $null,

        [Parameter(ParameterSetName = 'update')]
        [Parameter(ParameterSetName = 'bulk_update')]
        [Parameter(Mandatory = $true)]
        $data

    )

    $resource_uri = ('/organizations/{0}' -f $id)

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'bulk_update') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if($filter_organization_type_id) {
            $body += @{'filter[organization_type_id]' = $filter_organization_type_id}
        }
        if($filter_organization_status_id) {
            $body += @{'filter[organization_status_id]' = $filter_organization_status_id}
        }
        if($filter_created_at) {
            $body += @{'filter[created_at]' = $filter_created_at}
        }
        if($filter_updated_at) {
            $body += @{'filter[updated_at]' = $filter_updated_at}
        }
        if($filter_my_glue_account_id) {
            $body += @{'filter[my_glue_account_id]' = $filter_my_glue_account_id}
        }
        if($filter_exclude_id) {
            $body += @{'filter[exclude][id]' = $filter_exclude_id}
        }
        if($filter_exclude_name) {
            $body += @{'filter[exclude][name]' = $filter_exclude_name}
        }
        if($filter_exclude_organization_type_id) {
            $body += @{'filter[exclude][organization_type_id]' = $filter_exclude_organization_type_id}
        }
        if($filter_exclude_organization_status_id) {
            $body += @{'filter[exclude][organization_status_id]' = $filter_exclude_organization_status_id}
        }
    }

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Remove-ITGlueOrganizations {
    [CmdletBinding(DefaultParameterSetName = 'bulk_destroy')]
    Param (
        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_organization_type_id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_organization_status_id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [String]$filter_created_at = '',

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [String]$filter_updated_at = '',

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_my_glue_account_id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_exclude_id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [String]$filter_exclude_name = '',

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_exclude_organization_type_id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_exclude_organization_status_id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Parameter(Mandatory = $true)]
        $data

    )

    $resource_uri = ('/organizations/{0}' -f $id)

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'bulk_destroy') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if($filter_organization_type_id) {
            $body += @{'filter[organization_type_id]' = $filter_organization_type_id}
        }
        if($filter_organization_status_id) {
            $body += @{'filter[organization_status_id]' = $filter_organization_status_id}
        }
        if($filter_created_at) {
            $body += @{'filter[created_at]' = $filter_created_at}
        }
        if($filter_updated_at) {
            $body += @{'filter[updated_at]' = $filter_updated_at}
        }
        if($filter_my_glue_account_id) {
            $body += @{'filter[my_glue_account_id]' = $filter_my_glue_account_id}
        }
        if($filter_exclude_id) {
            $body += @{'filter[exclude][id]' = $filter_exclude_id}
        }
        if($filter_exclude_name) {
            $body += @{'filter[exclude][name]' = $filter_exclude_name}
        }
        if($filter_exclude_organization_type_id) {
            $body += @{'filter[exclude][organization_type_id]' = $filter_exclude_organization_type_id}
        }
        if($filter_exclude_organization_status_id) {
            $body += @{'filter[exclude][organization_status_id]' = $filter_exclude_organization_status_id}
        }
    }

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'DELETE' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function New-ITGlueOrganizationStatuses {
    Param (
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/organization_statuses/'

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGlueOrganizationStatuses {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'id', 'created_at', 'updated_at', `
                '-name', '-id', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/organization_statuses/{0}' -f $id)

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGlueOrganizationStatuses {
    Param (
        [Parameter(Mandatory = $true)]
        [Int64]$id,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/organization_statuses/{0}' -f $id)

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function New-ITGlueOrganizationTypes {
    Param (
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/organization_types/'

    $body = @{}

    $body = @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGlueOrganizationTypes {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'id', 'created_at', 'updated_at', `
                '-name', '-id', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/organization_types/{0}' -f $id)

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }


    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function Set-ITGlueOrganizationTypes {
    Param (
        [Parameter(Mandatory = $true)]
        [Int64]$id,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/organization_types/{0}' -f $id)

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function New-ITGluePasswordCategories{
    Param (
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/password_categories/'

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGluePasswordCategories {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'created_at', 'updated_at', `
                '-name', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/password_categories/{0}' -f $id)

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGluePasswordCategories {
    Param (
        [Parameter(Mandatory = $true)]
        [Int64]$id,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/password_categories/{0}' -f $id)

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function New-ITGluePasswords {
    Param (
        [Nullable[Int64]]$organization_id = $null,

        [Boolean]$show_password = $true, # Passwords API defaults to $false

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = '/passwords/'

    if ($organization_id) {
        $resource_uri = ('/organizations/{0}/relationships/passwords' -f $organization_id)
    }

    if (!$show_password) {
        $resource_uri = $resource_uri + ('?show_password=false') # using $False in PS results in 'False' (uppercase false), so explicitly writing out 'false' is needed
    }

    $body = @{}

    $body += @{'data'= $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'POST' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Get-ITGluePasswords {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$organization_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_organization_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_password_category_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_url = '',

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_cached_resource_name = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'username', 'id', 'created_at', 'updated-at', `
                '-name', '-username', '-id', '-created_at', '-updated-at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int64]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null,

        [Parameter(ParameterSetName = 'show')]
        [Boolean]$show_password = $true, # Passwords API defaults to $true

        [Parameter(ParameterSetName = 'index')]
        [Parameter(ParameterSetName = 'show')]
        $include = ''
    )

    $resource_uri = ('/passwords/{0}' -f $id)

    if ($organization_id) {
        $resource_uri = ('/organizations/{0}/relationships/passwords/{1}' -f $organization_id, $id)
    }

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_id) {$body += @{'filter[id]' = $filter_id}
        }
        if ($filter_name) {$body += @{'filter[name]' = $filter_name}
        }
        if ($filter_organization_id) {$body += @{'filter[organization_id]' = $filter_organization_id}
        }
        if ($filter_password_category_id) {$body += @{'filter[password_category_id]' = $filter_password_category_id}
        }
        if ($filter_url) {$body += @{'filter[url]' = $filter_url}
        }
        if ($filter_cached_resource_name) {$body += @{'filter[cached_resource_name]' = $filter_cached_resource_name}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {$body += @{'page[number]' = $page_number}
        }
        if ($page_size) {$body += @{'page[size]' = $page_size}
        }
    }
    elseif ($null -eq $organization_id) {
        #Parameter set "Show" is selected and no organization id is specified; switch from nested relationships route
        $resource_uri = ('/passwords/{0}' -f $id)
    }

    if (!$show_password) {
        $resource_uri = $resource_uri + ('?show_password=false') # using $False in PS results in 'False' (uppercase false), so explicitly writing out 'false' is needed
    }

    if($include) {
        $body += @{'include' = $include}
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGluePasswords {
    [CmdletBinding(DefaultParameterSetName = 'update')]
    Param (
        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$organization_id = $null,

        [Parameter(ParameterSetName = 'update')]
        [Nullable[Int64]]$id = $null,

        [Parameter(ParameterSetName = 'update')]
        [Boolean]$show_password = $false, # Passwords API defaults to $false

        [Parameter(ParameterSetName = 'update')]
        [Parameter(ParameterSetName = 'bulk_update')]
        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/passwords/{0}' -f $id)

    if ($organization_id) {
        $resource_uri = ('/organizations/{0}/relationships/passwords/{1}' -f $organization_id, $id)
    }

    if ($show_password) {
        $resource_uri = $resource_uri + ('?show_password=true') # using $True in PS results in 'True' (uppercase T), so explicitly writing out 'true' is needed
    }

    $body = @{}

    $body += @{'data' = $data}

    $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Remove-ITGluePasswords {
    [CmdletBinding(DefaultParameterSetName = 'destroy')]
    Param (
        [Parameter(ParameterSetName = 'destroy')]
        [Nullable[Int64]]$id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_organization_id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [Nullable[Int64]]$filter_password_category_id = $null,

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [String]$filter_url = '',

        [Parameter(ParameterSetName = 'bulk_destroy')]
        [String]$filter_cached_resource_name = '',

        [Parameter(ParameterSetName = 'bulk_destroy', Mandatory = $true)]
        $data
    )

    $resource_uri = ('/passwords/{0}' -f $id)

    $body = @{}

    if ($PSCmdlet.ParameterSetName -eq 'bulk_destroy') {
        if ($filter_id) {
            $body += @{'filter[id]' = $filter_id}
        }
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($filter_organization_id) {
            $body += @{'filter[organization_id]' = $filter_organization_id}
        }
        if ($filter_password_category_id) {
            $body += @{'filter[password_category_id]' = $filter_password_category_id}
        }
        if ($filter_url) {
            $body += @{'filter[url]' = $filter_url}
        }
        if ($filter_cached_resource_name) {
            $body += @{'filter[cached_resource_name]' = $filter_cached_resource_name}
        }

        $body += @{'data' = $data}

        $body = ConvertTo-Json -InputObject $body -Depth $ITGlue_JSON_Conversion_Depth
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'DELETE' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function Get-ITGluePlatforms {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'id', 'created_at', 'updated_at', `
                '-name', '-id', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/platforms/{0}' -f $id)

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function Get-ITGlueRegions {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$country_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_iso = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int]]$filter_country_id = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'id', 'created_at', 'updated_at', `
                '-name', '-id', '-created_at', '-updated_at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/regions/{0}' -f $id)
    if ($country_id) {
        $resource_uri = ('/countries/{0}/relationships' -f $country_id) + $resource_uri
    }

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($filter_iso) {
            $body += @{'filter[iso]' = $filter_iso}
        }
        if ($filter_country_id) {
            $body += @{'filter[country_id]' = $filter_country_id}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function Get-ITGlueUserMetrics {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_user_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$filter_organization_id = $null,

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_resource_type = '',

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_date = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'id', 'created', 'viewed', 'edited', 'deleted', 'date', `
                '-id', '-created', '-viewed', '-edited', '-deleted', '-date')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null
    )

    $resource_uri = '/user_metrics'

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_user_id) {
            $body += @{'filter[user_id]' = $filter_user_id}
        }
        if ($filter_organization_id) {
            $body += @{'filter[organization_id]' = $filter_organization_id}
        }
        if ($filter_resource_type) {
            $body += @{'filter[resource_type]' = $filter_resource_type}
        }
        if ($filter_date) {
            $body += @{'filter[date]' = $filter_date}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}
function Get-ITGlueUsers {
    [CmdletBinding(DefaultParameterSetName = 'index')]
    Param (
        [Parameter(ParameterSetName = 'index')]
        [String]$filter_name = '',

        [Parameter(ParameterSetName = 'index')]
        [String]$filter_email = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet('Administrator', 'Manager', 'Editor', 'Creator', 'Lite', 'Read-only')]
        [String]$filter_role_name = '',

        [Parameter(ParameterSetName = 'index')]
        [ValidateSet( 'name', 'email', 'reputation', 'id', 'created_at', 'updated-at', `
                '-name', '-email', '-reputation', '-id', '-created_at', '-updated-at')]
        [String]$sort = '',

        [Parameter(ParameterSetName = 'index')]
        [Nullable[Int64]]$page_number = $null,

        [Parameter(ParameterSetName = 'index')]
        [Nullable[int]]$page_size = $null,

        [Parameter(ParameterSetName = 'show')]
        [Nullable[Int64]]$id = $null
    )

    $resource_uri = ('/users/{0}' -f $id)

    if ($PSCmdlet.ParameterSetName -eq 'index') {
        if ($filter_name) {
            $body += @{'filter[name]' = $filter_name}
        }
        if ($filter_email) {
            $body += @{'filter[email]' = $filter_email}
        }
        if ($filter_role_name) {
            $body += @{'filter[role_name]' = $filter_role_name}
        }
        if ($sort) {
            $body += @{'sort' = $sort}
        }
        if ($page_number) {
            $body += @{'page[number]' = $page_number}
        }
        if ($page_size) {
            $body += @{'page[size]' = $page_size}
        }
    }

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'GET' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}

function Set-ITGlueUsers {
    Param (
        [Parameter(Mandatory = $true)]
        [Int64]$id,

        [Parameter(Mandatory = $true)]
        $data
    )

    $resource_uri = ('/users/{0}' -f $id)

    $body = ConvertTo-Json -InputObject $data -Depth $ITGlue_JSON_Conversion_Depth

    try {
        $ITGlue_Headers.Add('x-api-key', (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'N/A', $ITGlue_API_Key).GetNetworkCredential().Password)
        $rest_output = Invoke-RestMethod -method 'PATCH' -uri ($ITGlue_Base_URI + $resource_uri) -headers $ITGlue_Headers `
            -body $body -ErrorAction Stop -ErrorVariable $web_error
    } catch {
        Write-Error $_
    } finally {
        [void] ($ITGlue_Headers.Remove('x-api-key')) # Quietly clean up scope so the API key doesn't persist
    }

    $data = @{}
    $data = $rest_output
    return $data
}




$FlexAssetName = "Printers"
$Description = "All configuration settings for printers and a backup of their respective drivers"
$TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"
$InstallPrintManagement = $true
$BackupDriver = $true
$RmmComputer = (Get-RmmComputer -Computer $(Get-ImmyComputer) -ProviderType CWAutomate).RmmDeviceId

Add-ITGlueBaseURI -base_uri $APIURL
Add-ITGlueAPIKey $APIKEy


#Checking if the FlexibleAsset exists. If not, create a new one.
$FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
if (!$FilterID) { 
    $NewFlexAssetData = 
    @{
        type          = 'flexible-asset-types'
        attributes    = @{
            name        = $FlexAssetName
            icon        = 'sitemap'
            description = $description
        }
        relationships = @{
            "flexible-asset-fields" = @{
                data = @(
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order           = 1
                            name            = "Printer Name"
                            kind            = "Text"
                            required        = $true
                            "show-in-list"  = $true
                            "use-for-title" = $true
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order           = 2
                            name            = "Location"
                            kind            = "Text"
                            required        = $false
                            "show-in-list"  = $true
                            "use-for-title" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order           = 3
                            name            = "Comment"
                            kind            = "Text"
                            required        = $false
                            "show-in-list"  = $false
                            "use-for-title" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 4
                            name           = "Printer Config"
                            kind           = "Text"
                            required       = $false
                            "show-in-list" = $true
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 5
                            name           = "Port Config"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 6
                            name           = "Printer Properties"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 7
                            name           = "Printer Driver"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 8
                            name           = "Print Server"
                            kind           = "Tag"
                            "tag-type"     = "Configurations"
                            required       = $false
                            "show-in-list" = $true
                        }
                    }
                )
            }
        }
                 
    }
    New-ITGlueFlexibleAssetTypes -Data $NewFlexAssetData
    $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
} 

###################### Variable Setup ######################
Write-Host "RMM Computer ID is: $AutomateComputerID"
$RMM_Asset = (Get-ITGlueConfigurations -filter_rmm_integration_type automate -filter_rmm_id $RmmComputer).data
 $orgID = $RMM_Asset.attributes.'organization-id'
 Write-Host "ITGlue Org ID is: $orgID"
 $computerAssetID = $RMM_Asset.id
 Write-Host "RMM Computer ID is: $computerAssetID"
$FlexAssetName = "File Share Permissions"
$Description = "File Share Permissions (Auto Documented)"
$TagRelatedDevices = $true
$HTMLBody = @()

#Only continue if we've succesfully matched to an ITGlue Org ID.
#Otherwise there's no point in trying to document. 
if ($orgID) {


#Tagging devices
<#    $DeviceAsset = @()
    If($TagRelatedDevices -eq $true){
        Write-Host "Finding all related resources - Based on computername: $ENV:COMPUTERNAME"
        $DeviceAsset += (Get-ITGlueConfigurations -page_size "1000" -filter_name $ENV:COMPUTERNAME -organization_id $orgID).data
        } 
#>   

###################### Get all existing assets for API call optimisation ######################
$AllPrinterAssets = (Get-ITGlueFlexibleAssets -page_size 1000 -filter_flexible_asset_type_id $FilterID.id -filter_organization_id $orgID).data


$FlexAssetArray = Invoke-ImmyCommand {

    function Transpose-Object
    { [CmdletBinding()]
    Param([OBJECT][Parameter(ValueFromPipeline = $TRUE)]$InputObject)

    BEGIN
    { # initialize variables just to be "clean"
        $Props = @()
        $PropNames = @()
        $InstanceNames = @()
    }

    PROCESS
    {
        if ($Props.Length -eq 0)
        { # when first object in pipeline arrives retrieve its property names
                $PropNames = $InputObject.PSObject.Properties | Select-Object -ExpandProperty Name
                # and create a PSCustomobject in an array for each property
                $InputObject.PSObject.Properties | %{ $Props += New-Object -TypeName PSObject -Property @{Property = $_.Name} }
            }

            if ($InputObject.Name)
            { # does object have a "Name" property?
                $Property = $InputObject.Name
            } else { # no, take object itself as property name
                $Property = $InputObject | Out-String
            }

            if ($InstanceNames -contains $Property)
            { # does multiple occurence of name exist?
            $COUNTER = 0
                do { # yes, append a number in brackets to name
                    $COUNTER++
                    $Property = "$($InputObject.Name) ({0})" -f $COUNTER
                } while ($InstanceNames -contains $Property)
            }
            # add current name to name list for next name check
            $InstanceNames += $Property

        # retrieve property values and add them to the property's PSCustomobject
        $COUNTER = 0
        $PropNames | %{
            if ($InputObject.($_))
            { # property exists for current object
                $Props[$COUNTER] | Add-Member -Name $Property -Type NoteProperty -Value $InputObject.($_)
            } else { # property does not exist for current object, add $NULL value
                $Props[$COUNTER] | Add-Member -Name $Property -Type NoteProperty -Value $NULL
            }
                $COUNTER++
        }
    }

    END
    {
        # return collection of PSCustomobjects with property values
        $Props
    }
    }

    $TableStyling = $using:TableStyling
    $BackupDriver = $using:BackupDriver
    $PrintManagementInstalled = get-windowsfeature -name 'RSAT-Print-Services' -ErrorAction SilentlyContinue
    if ($InstallPrintManagement -and !$PrintManagementInstalled) {
        Add-WindowsFeature -Name 'RSAT-Print-Services'
    }
    import-module PrintManagement
    $PrinterList = Get-Printer
    
    $PrinterConfigurations = foreach ($Printer in $PrinterList) {
        $PrinterConfig = Get-PrintConfiguration -PrinterName $printer.Name
        $PortConfig = get-printerport -Name $printer.PortName
        $PrinterProperties = Get-PrinterProperty -PrinterName $printer.Name
        $PrinterDriver = Get-PrinterDriver -Name $printer.DriverName | select Name, ConfigFile, DataFile, DriverVersion, HelpFile, InfPath, MajorVersion, Manufacturer, OEMUrl, Path, PrinterEnvironment, PrintProcessor, provider #| ForEach-Object { $_.InfPath; $_.ConfigFile; $_.DataFile; $_.DependentFiles } | Where-Object { $_ -ne $null }
        if ($BackupDriver) {
            #$Driver = Get-PrinterDriver -Name $printer.DriverName | ForEach-Object { $_.InfPath; $_.ConfigFile; $_.DataFile; $_.DependentFiles } | Where-Object { $_ -ne $null }
            #$BackupPath = new-item -path "$($ENV:TEMP)\$($printer.name)" -ItemType directory -Force
            
            #$Driver | foreach-object { copy-item -path $_ -Destination "$($ENV:TEMP)\$($printer.name)" -Force }
            #Add-Type -assembly "system.io.compression.filesystem"
            #[io.compression.zipfile]::CreateFromDirectory("$($ENV:TEMP)\$($printer.name)", "$($ENV:TEMP)\$($printer.name).zip")
            #$ZippedDriver = ([convert]::ToBase64String(([IO.File]::ReadAllBytes("$($ENV:TEMP)\$($printer.name).zip"))))
            #remove-item "$($ENV:TEMP)\$($printer.name)" -force -Recurse
            #remove-item "$($ENV:TEMP)\$($printer.name).zip" -force -Recurse
        }
        New-Object PSObject -Property @{
            PrinterName       = $printer.name
            PrinterLocation   = $printer.location
            PrinterComment    = $printer.comment
            PrinterConfig     = $PrinterConfig | select-object DuplexingMode, PapierSize, Collate, Color | convertto-html -Fragment | Out-String
            PortConfig        = $PortConfig  | Select-Object Description, Name, PortNumber, PrinterHostAddress, snmpcommunity, snmpenabled | convertto-html -Fragment | out-string
            PrinterProperties = $PrinterProperties | Select-Object PropertyName, Value | convertto-html -Fragment | out-string
            PrinterDriver     = $($PrinterDriver | Transpose-Object | convertto-html -Fragment | out-string) -replace $TableStyling
        }
    }
$FlexAssetArray = @()  
    foreach ($printerconf in $PrinterConfigurations) {
        Write-Host $printerconf.ZippedDriver
        $FlexAsset = 
        @{
            type       = 'flexible-assets'
            attributes = @{
                name   = $FlexAssetName
                traits = @{
                    "printer-name"       = $printerconf.Printername
                    "location"           = $printerconf.PrinterLocation
                    "comment"            = $printerconf.PrinterComment
                    "printer-config"     = $printerconf.printerconfig
                    "port-config"        = $printerconf.portconfig
                    "printer-properties" = $printerconf.PrinterProperties
                    "printer-driver"     = $printerconf.PrinterDriver
                }
            }
        }
    $FlexAssetArray += $FlexAsset
    }
return $FlexAssetArray
} -Timeout 360

$ITGlueObjectUpdateArray = @()
foreach ($FlexAssetBody in $FlexAssetArray) {

    #$FlexAssetBody.attributes.traits.'printer-driver'
    #Upload data to IT-Glue. We try to match the Server name to current computer name.
    $ExistingFlexAsset = $AllPrinterAssets | Where-Object { $_.attributes.traits.'printer-name' -eq $FlexAssetBody.attributes.traits.'printer-name' }
    #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
    $FlexAssetBody.attributes.traits.add('print-server', $computerAssetID)
    if (!$ExistingFlexAsset) {
        $FlexAssetBody.attributes.add('organization-id', $orgID)
        $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
        
        Write-Host "Creating new flexible asset"
        New-ITGlueFlexibleAssets -data $FlexAssetBody
        #Set-ITGlueFlexibleAssets -id $newID.ID -data $Attachment
    }
    else {
        Write-Host "Updating Flexible Asset"
        $ExistingFlexAsset = $ExistingFlexAsset | select-object -last 1
        $FlexAssetBody.attributes.add('id', $ExistingFlexAsset.id)
        #Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody
        $ITGlueObjectUpdateArray += $FlexAssetBody
    }


}

} else { Write-Ouput "Not matched to an ITGlue organisation."}
Set-ITGlueFlexibleAssets -data $ITGlueObjectUpdateArray -Verbose
