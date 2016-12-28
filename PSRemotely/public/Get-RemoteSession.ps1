function Get-RemoteSession
{
<#
	.SYNOPSIS
	Function which lists out all the PSSessions in use by PSRemotely.
    The session name follow the naming convention of -> PSRemotely-<NodeName>

	.NOTES
	Read the documentation hosted on GitHub for the project for using the DSL.
	
	.LINK
	PSRemotely
    Node
	Invoke-PSRemotely
    Clear-RemoteSession

#>
    $sessions = @()
    foreach($sessionInfo in $Global:PSRemotely.sessionHashTable.Values.GetEnumerator())
    {
        $sessions += $sessionInfo.Session
    }
    $sessions
}
