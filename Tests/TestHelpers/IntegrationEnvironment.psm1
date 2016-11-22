<#
    .Synopsis
        Function which will Initialize the localhost for the PS Remotely integration testing.

    .DESCRIPTION
        The function does the below:
        - Call Remotely\Clear-RemoteSession to clear the existing remote session.
        - Restart the WinRM service, just in case.
#>

Function Clear-RemotelyNodePath {
    param()

    $RemotelyJSONFile = "$Env:BHPSModulePath\Remotely.json"
    $RemotelyConfig = ConvertFrom-Json -InputObject (Get-Content $RemotelyJSONFile)

    Remove-Item -Path $RemotelyConfig.RemotelyNodePath -Recurse -Force
}

# Credits : Picked these helpers from the DSC Resources repo 
<#
    .SYNOPSIS
        Creates a user account.

    .DESCRIPTION
        This function creates a user on the local or remote machine.

    .PARAMETER Credential
        The credential containing the username and password to use to create the account.

    .PARAMETER Description
        The optional description to set on the user account.

    .PARAMETER ComputerName
        The optional name of the computer to update. Omit to create a user on the local machine.

    .NOTES
        For remote machines, the currently logged on user must have rights to create a user.
#>
function New-User
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [System.String]
        $Description,

        [System.String]
        $ComputerName = $env:COMPUTERNAME
    )

    Set-StrictMode -Version Latest

    $userName = $Credential.UserName
    $password = $Credential.GetNetworkCredential().Password

    # Remove user if it already exists.
    Remove-User $userName $ComputerName

    $adComputerEntry = [ADSI] "WinNT://$ComputerName"
    $adUserEntry = $adComputerEntry.Create('User', $userName)
    $null = $adUserEntry.SetPassword($password)

    if ($PSBoundParameters.ContainsKey('Description'))
    {
        $null = $adUserEntry.Put('Description', $Description)
    }

    $null = $adUserEntry.SetInfo()
}


<#
    .SYNOPSIS
        Removes a user account.

    .DESCRIPTION
        This function removes a local user from the local or remote machine.

    .PARAMETER UserName
        The name of the user to remove.

    .PARAMETER ComputerName
        The optional name of the computer to update. Omit to remove the user on the local machine.

    .NOTES
        For remote machines, the currently logged on user must have rights to remove a user.
#>
function Remove-User
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $UserName,

        [System.String]
        $ComputerName = $env:COMPUTERNAME
    )

    Set-StrictMode -Version Latest

    $adComputerEntry = [ADSI] "WinNT://$ComputerName"

    if ($adComputerEntry.Children | Where-Object Path -like "WinNT://*$ComputerName/$UserName")
    {
        $null = $adComputerEntry.Delete('user', $UserName)
    }
}


function Add-LocalUserToLocalAdminGroup 
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $UserName,

        [System.String]
        $ComputerName = $env:COMPUTERNAME
    )
    Set-StrictMode -Version Latest
    $AdminGroup = [ADSI]"WinNT://$ComputerName/Administrators,group"
    $LocalUser = [ADSI]"WinNT://$ComputerName/$userName,user"
    if ($LocalUser) 
    {
        $AdminGroup.Add($LocalUser)
    }
    else 
    {
        Write-Warning -Message "Local user -> $UserName does not exist on $ComputerName"
    }
}