function Clear-RemoteSession
{
    foreach($sessionInfo in $Global:Remotely.sessionHashTable.Values.GetEnumerator()){
        Remove-PSSession $sessionInfo.Session
    }

    $Global:Remotely.sessionHashTable.Clear()
    $Global:Remotely.NodeMap.Clear()    
    
}