function Remotely
{
    param 
    (       
        # DSC style configuration data , follows the same syntax
		[Parameter(Mandatory, Position = 0)]
        [hashtable] $ConfigurationData=@{
			AllNodes=@()
		},
        
		# The Pester Describe block which gets executed on the remotely node.
        [Parameter(Mandatory = $true, Position = 1)]
        [ScriptBlock] $test,

		# Key-Value pairs corresponding to variable-value which are passed to the remotely node.
        [Parameter(Mandatory = $false, Position = 2)]
        [Hashtable]$ArgumentList,

		# Probably below won't be needed if the Configuration data implementation is done.
        [Parameter(Mandatory = $false, Position = 3)]
        $CredentialHash = @{}
    )
	
	#region parse configuration data passed
	Validate-ConfigData -ConfigurationData $ConfigurationData

	$ConfigurationData = Update-ConfigData -ConfigurationData $ConfigurationData

	# Variables to be defined in the remotely session
	$VariablesToDefine =  @(
		if ($ConfigurationData){
			New-Object -Typename PSVariable -ArgumentList ('AllNodes',$ConfigurationData.AllNodes)
		}
	)

	$VariablesToDefine += foreach ($key in $ArgumentList.Keys) {
		New-Object -TypeName PSVariable -ArgumentList ($key, $ArgumentList[$key])
	}
	

	# parse and validate the Pester describe block

	# parse the configuration data and re-use it while creating remotely sessions

	#endregion

    if ($script:sessionsHashTable -eq $null)
    {
        $script:sessionsHashTable = @{}
    }

	#region write a temp file with the test content
    $tempFile = "$env:APPDATA\tempPester.Tests.ps1"
    Set-Content -Value $test -Path $tempFile

	#endregion

	#region create session & bootstrap nodes
    CreateSessions -Nodes $Nodes -CredentialHash $CredentialHash
    
    $sessions = @()
    foreach($sessionInfo in $script:sessionsHashTable.Values.GetEnumerator())
    {
        CheckAndReConnect -sessionInfo $sessionInfo
        $sessions += $sessionInfo.Session
        BootstrapRemotelyNode -Session $sessionInfo.Session
    }

    if($sessions.Count -le 0)
    {
        throw "No sessions are available"
    }
	
	#endregion    
    
    $testjob = Invoke-Command -Session $sessions -ScriptBlock {
                $using:ModulesRequired | 
                Foreach {
                     "Importing ($using:RemotelyNodePath\$Psitem\$PSitem.psd1)"
                    Import-Module "$using:RemotelyNodePath\$Psitem\$PSitem.psd1";
                }
                Invoke-Pester -Script C:\temp\tempPester.Tests.ps1} -AsJob -ArgumentList $ArgumentList | Wait-Job

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