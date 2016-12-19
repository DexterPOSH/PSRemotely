<#
    .Synopsis
        Function which will Initialize the localhost for the PS Remotely integration testing.

    .DESCRIPTION
        The function does the below:
        - Call Remotely\Clear-RemoteSession to clear the existing remote session.
        - Restart the WinRM service, just in case.
#>

Function Clear-PSRemotelyNodePath {
    param($Remotely)

    Remove-Item -Path $Global:Remotely.RemotelyNodePath -Recurse -Force
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
    $null = net localgroup Administrators PSRemotely /ADD
     
}

<#
    Below functions are needed to disable/enable the LocalAccountTokenFilterPolicy.
    Copying the relevant section on the loopback attacks from the link here ->  https://support.microsoft.com/en-in/kb/951016

    - How UAC remote restrictions work

        To better protect those users who are members of the local Administrators group, we implement UAC restrictions on the network. 
        This mechanism helps prevent against "loopback" attacks. This mechanism also helps prevent local malicious software from running remotely with administrative rights.
        
    - Local user accounts (Security Account Manager user account)

        When a user who is a member of the local administrators group on the target remote computer establishes a remote administrative 
        connection by using the net use * \\remotecomputer\Share$ command, for example, they will not connect as a full administrator. 
        The user has no elevation potential on the remote computer, and the user cannot perform administrative tasks. 
        If the user wants to administer the workstation with a Security Account Manager (SAM) account, 
        the user must interactively log on to the computer that is to be administered with Remote Assistance or Remote Desktop, if these services are available.

    - Domain user accounts (Active Directory user account)

        A user who has a domain user account logs on remotely to a Windows Vista computer. 
        And, the domain user is a member of the Administrators group. 
        In this case, the domain user will run with a full administrator access token on the remote computer, and UAC will not be in effect. 

    - UAC remote settings

        The LocalAccountTokenFilterPolicy registry entry in the registry can have a value of 0 or of 1. 
        These values change the behavior of the registry entry to the behavior that is described in the following table.
        Value	Description
        0	This value builds a filtered token. This is the default value. The administrator credentials are removed.
        1	This value builds an elevated token.
#>
Function Disable-LocalAccountTokenFilterPolicy {
    param()
    Set-ItemProperty -path HkLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\  -Name LocalAccountTokenFilterPolicy -Value 1
}

Function Enable-LocalAccountTokenFilterPolicy {
    param()
    Set-ItemProperty -path HkLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\  -Name LocalAccountTokenFilterPolicy -Value 0
}


<#
    Functions to replace the machine name in the .JSON or PSD1 files
#>

Function Expand-ComputerName {
    param($Path)

    $FileContent = Get-Content -Path $Path -Raw
    $FileContent = $FileContent.Replace('$env:COMPUTERNAME',"$($env:COMPUTERNAME)")
    $FileContent
}
