function Remotely
{
    param 
    (       
        [Parameter(Mandatory, Position = 0)]
        [String[]] $Nodes,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [ScriptBlock] $test,

        [Parameter(Mandatory = $false, Position = 2)]
        $ArgumentList,

        [Parameter(Mandatory = $false, Position = 3)]
        $CredentialHash = @{}
    )

    if ($script:sessionsHashTable -eq $null)
    {
        $script:sessionsHashTable = @{}
    }
    

    CreateSessions -Nodes $Nodes -CredentialHash $CredentialHash
    
    $sessions = @()
    foreach($sessionInfo in $script:sessionsHashTable.Values.GetEnumerator())
    {
        CheckAndReConnect -sessionInfo $sessionInfo
        $sessions += $sessionInfo.Session
    }

    if($sessions.Count -le 0)
    {
        throw "No sessions are available"
    }
    
    $testjob = Invoke-Command -Session $sessions -ScriptBlock $test -AsJob -ArgumentList $ArgumentList | Wait-Job

    $results = @()

    foreach($childJob in $testjob.ChildJobs)
    {
        if($childJob.Output.Count -eq 0)
        {
            [object] $outputStream = New-Object psobject
        }
        else
        {
            [object] $outputStream = $childJob.Output | % { $_ }
        }

        $errorStream =    CopyStreams $childJob.Error
        $verboseStream =  CopyStreams $childJob.Verbose
        $debugStream =    CopyStreams $childJob.Debug
        $warningStream =  CopyStreams $childJob.Warning
        $progressStream = CopyStreams $childJob.Progress    
    
        $allStreams = @{ 
                            Error = $errorStream
                            Verbose = $verboseStream
                            DebugOutput = $debugStream
                            Warning = $warningStream
                            ProgressOutput = $progressStream
                        }
    
        $outputStream = Add-Member -InputObject $outputStream -PassThru -MemberType NoteProperty -Name __Streams -Value $allStreams
        $outputStream = Add-Member -InputObject $outputStream -PassThru -MemberType ScriptMethod -Name GetError -Value { return $this.__Streams.Error }
        $outputStream = Add-Member -InputObject $outputStream -PassThru -MemberType ScriptMethod -Name GetVerbose -Value { return $this.__Streams.Verbose }
        $outputStream = Add-Member -InputObject $outputStream -PassThru -MemberType ScriptMethod -Name GetDebugOutput -Value { return $this.__Streams.DebugOutput }
        $outputStream = Add-Member -InputObject $outputStream -PassThru -MemberType ScriptMethod -Name GetProgressOutput -Value { return $this.__Streams.ProgressOutput }
        $outputStream = Add-Member -InputObject $outputStream -PassThru -MemberType ScriptMethod -Name GetWarning -Value { return $this.__Streams.Warning }
        $outputStream = Add-Member -InputObject $outputStream -PassThru -MemberType NoteProperty -Name RemotelyTarget -Value $childJob.Location

        if($childJob.State -eq 'Failed')
        {
	        $childJob | Receive-Job -ErrorAction SilentlyContinue -ErrorVariable jobError
	        $outputStream.__Streams.Error = $jobError
        }

        $results += ,$outputStream
    }

    $testjob | Remove-Job -Force
    $results
}

function CopyStreams
{
    param
    (
        [Parameter(Position=0, Mandatory=$true)] 
        $inputStream
    ) 

    $outStream = New-Object 'System.Management.Automation.PSDataCollection[PSObject]'

    foreach($item in $inputStream)
    {
        $outStream.Add($item)
    }

    $outStream.Complete()

    ,$outStream
}

function CreateSessions
{
    param
    (
        [Parameter(Mandatory)]
        [string[]] $Nodes,

        [Parameter()]
        $CredentialHash
    )
               
    foreach($Node in $Nodes)
    { 
        if(-not $script:sessionsHashTable.ContainsKey($Node))
        {                                   
            $sessionName = "Remotely-" + $Node                              
            if ($CredentialHash -and $CredentialHash[$Node])
            {
                $sessionInfo = CreateSessionInfo -Session (New-PSSession -ComputerName $Node -Name $sessionName -Credential $CredentialHash[$node]) -Credential $CredentialHash[$node]
            }
            else
            {
                $sessionInfo = CreateSessionInfo -Session (New-PSSession -ComputerName $Node -Name $sessionName)  
            }
            $script:sessionsHashTable.Add($sessionInfo.session.ComputerName, $sessionInfo)              
        }               
    }
}

function CreateLocalSession
{    
    param(
        [Parameter(Position=0)] $Node = 'localhost'
    )

    if(-not $script:sessionsHashTable.ContainsKey($Node))
    {
        $sessionInfo = CreateSessionInfo -Session (New-PSSession -ComputerName $Node -Name $sessionName)
        $script:sessionsHashTable.Add($Node, $sessionInfo)
    } 
}

function CreateSessionInfo
{
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Runspaces.PSSession] $Session,

        [Parameter(Position=1)]
        [pscredential] $Credential
    )
    return [PSCustomObject] @{ Session = $Session; Credential = $Credential}
}

function CheckAndReconnect
{
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()] $sessionInfo
    )

    if($sessionInfo.Session.State -ne [System.Management.Automation.Runspaces.RunspaceState]::Opened)
    {
        Write-Verbose "Unexpected session state: $sessionInfo.Session.State for machine $($sessionInfo.Session.ComputerName). Re-creating session" 
        if($sessionInfo.Session.ComputerName -ne 'localhost')
        {
            if ($sessionInfo.Credential)
            {
                $sessionInfo.Session = New-PSSession -ComputerName $sessionInfo.Session.ComputerName -Credential $sessionInfo.Credential
            }
            else
            {
                $sessionInfo.Session = New-PSSession -ComputerName $sessionInfo.Session.ComputerName
            }
        }
        else
        {
            $sessionInfo.Session = New-PSSession -ComputerName 'localhost'
        }
    }
}

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