Function Node {
    [OutputType([void])]
	[CmdletBinding()]
    param(
		[Parameter(Mandatory = $True,Position = 0,
					ValueFromPipeline = $True)]
		[String[]]$name,

		# The Pester Describe block which gets executed on the remotely node.
        [Parameter(Mandatory = $true, Position = 1)]
        [ScriptBlock] $testBlock

    )
	BEGIN {
		if($script:sessionsHashTable) {
			foreach($sessionInfo in $script:sessionsHashTable.Values.GetEnumerator())
			{
				$sessions += $sessionInfo.Session
			}
		}
		else {
			# this might mean that the Configuration data was never supplied
			# Check if the AllNodes Script var is present is not null
			New-Variable -Name remotelyNodeMap -Value @{} -Scope Script # Create a hashtable which will contain the bootstrap status
			if(-not $Script:AllNodes) {
				$script:sessionsHashTable = @{}
				# this means the session creation has to be done here
				$createSessionParam = @{Nodes=$name}
				if($Script:CredentialHash) {
					$createSessionParam.Add('CredentialHash', $Script:CredentialHash)
				}
				if($Script:ArgumentList) {
					$createSessionParam.Add('ArgumentList', $Script:ArgumentList)
				}
				CreateSessions @createSessionParam
				$sessions = @()
				if( $script:sessionsHashTable.Values.count -le 0) {
					throw 'No sessions created'
				}
				else {
					foreach($sessionInfo in $script:sessionsHashTable.Values.GetEnumerator())
					{
						CheckAndReConnect -sessionInfo $sessionInfo
						$sessions += $sessionInfo.Session
						if($Script:remotelyNodeMap.ContainsKey($($SessionInfo.Session.ComputerName))) {
							# In memory Node map, has the node marked as bootstrapped
						}
						else {
							# run the bootstrap function
							BootstrapRemotelyNode -Session $sessionInfo.Session -FullyQualifiedName $Script:modulesRequired
						}
					}
				}
			}
		}
		
		$testjob = @()
	}
	PROCESS {

		foreach($nodeName in $name)  {
			# get the test name from the Describe block
			$testName = Get-TestName -Content $testBlock
			# generate the test file name..naming convention -> NodeName.TestName.Tests.ps1
			$testFileName = "{0}.{1}.Tests.ps1" -f $nodeName,$testName

			# get the relevant Session for the node
			$session = $Sessions | Where-Object -FilterScript {$PSitem.ComputerName -eq $nodeName}
			$testjob = Invoke-Command -Session $session -ScriptBlock {
				param(
					[hashtable]$modulesRequired,
					[string]$remotelyNodePath,
					[String]$testFileName,
					[String]$name,
					[String]$testName

				)
                $modulesRequired | 
                Foreach {
                    Import-Module "$remotelyNodePath\$Psitem\$PSitem.psd1";
                }
				$testFile = "$remotelyNodePath\$testFileName"
				$outPutFile = "{0}\{1}.{2}.xml" -f 	 $remotelyNodePath, $name, $testName
				Set-Content -Path $testFile -Value $testBlock	-Force
				$pesterParams = @{}
				if ($Script) {
					$pesterParams.Add('Script',$Script)
				}
				if ($testName) {
					$pesterParams.Add('TestName',$testName)
				}
				# TODO check if Pester arguments are populated in as variables and use them there
				if($pesterParams.Count -ge 1) {
					Invoke-Pester @pesterParams -PassThru -Tag $tags -Quiet -OutputFormat NUnit -OutputFile $outPutFile
				}
				else {
					Invoke-Pester -Script $testFile -Tag $tags -PassThru -Quiet -OutputFormat NUnit -OutputFile $outPutFile
				}
                
			} -ArgumentList $Script:modulesRequired, $Script:remotelyNodePath, $testFileName , $nodeName, $testName -AsJob 
		}
	}
	END {
		$testjob | Wait-Job
		$results = @()

		foreach($childJob in $testjob.ChildJobs)
		{
			if($childJob.Output.Count -eq 0){
				[object] $outputStream = New-Object psobject
			}
			else {
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

			if($childJob.State -eq 'Failed'){
				$childJob | Receive-Job -ErrorAction SilentlyContinue -ErrorVariable jobError
				$outputStream.__Streams.Error = $jobError
			}

			$results += ,$outputStream
		}

    $testjob | Remove-Job -Force
    
		# Create the Object here as per the guideline
		# iterate over each result object and generate the new customobject for each
		foreach($result in $results) {
			$output = [PsCustomObject]@{
						NodeName=$result.RemotelyTarget
						Tests=@()
					}
			
		}

	}


	

	#endregion

}