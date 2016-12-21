function Clear-RemoteSession
{
    <#
	.SYNOPSIS
	Function which clears out all the PSSessions in use by PSRemotely.
    It will also update the global variable PSRemotely's NodeMap and sessionHashTable.

	.NOTES
	Read the documentation hosted on GitHub for the project for using the DSL.
	
	.LINK
	PSRemotely
    Node
	Invoke-PSRemotely
    Get-RemoteSession

#>
    foreach($sessionInfo in $Global:PSRemotely.sessionHashTable.Values.GetEnumerator()){
        Remove-PSSession $sessionInfo.Session
    }

    $Global:PSRemotely.sessionHashTable.Clear()
    $Global:PSRemotely.NodeMap = @() # NodeMap is a collection, so clear() method does not work as expected
    
}