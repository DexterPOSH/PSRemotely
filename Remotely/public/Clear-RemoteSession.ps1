function Clear-RemoteSession
{
    foreach($sessionInfo in $Global:Remotely.sessionHashTable.Values.GetEnumerator()){
        Remove-PSSession $sessionInfo.Session
    }

    $Global:Remotely.sessionHashTable.Clear()
    $Global:Remotely.NodeMap = @() # NodeMap is a collection, so clear() method does not work as expected
    
}