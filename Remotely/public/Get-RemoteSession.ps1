function Clear-RemoteSession
{
    foreach($sessionInfo in $script:sessionsHashTable.Values.GetEnumerator())
    {
        Remove-PSSession $sessionInfo.Session
    }

    $script:sessionsHashTable.Clear()
}

function Get-RemoteSession
{
    $sessions = @()
    foreach($sessionInfo in $script:sessionsHashTable.Values.GetEnumerator())
    {
        $sessions += $sessionInfo.Session
    }
    $sessions
}
