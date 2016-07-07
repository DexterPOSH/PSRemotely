function Get-RemoteSession
{
    $sessions = @()
    foreach($sessionInfo in $Global:Remotely.sessionsHashTable.Values.GetEnumerator())
    {
        $sessions += $sessionInfo.Session
    }
    $sessions
}
