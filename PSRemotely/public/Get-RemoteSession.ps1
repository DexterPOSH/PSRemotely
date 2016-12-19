function Get-RemoteSession
{
    $sessions = @()
    foreach($sessionInfo in $Global:PSRemotely.sessionHashTable.Values.GetEnumerator())
    {
        $sessions += $sessionInfo.Session
    }
    $sessions
}
