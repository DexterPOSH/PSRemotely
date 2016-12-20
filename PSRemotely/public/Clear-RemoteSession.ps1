function Clear-RemoteSession
{
    foreach($sessionInfo in $Global:PSRemotely.sessionHashTable.Values.GetEnumerator()){
        Remove-PSSession $sessionInfo.Session
    }

    $Global:PSRemotely.sessionHashTable.Clear()
    $Global:PSRemotely.NodeMap = @() # NodeMap is a collection, so clear() method does not work as expected
    
}