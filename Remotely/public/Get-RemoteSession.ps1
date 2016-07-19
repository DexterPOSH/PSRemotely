function Get-RemoteSession
{
    $sessions = @()
    foreach($sessionInfo in $Global:Remotely.sessionHashTable.Values.GetEnumerator())
    {
        $sessions += $sessionInfo.Session
    }
    $sessions
}
