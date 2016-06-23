Function ProcessRemotelyJobs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Object[]]$InputObject  
    )
    
    foreach($childJob in $InputObject.ChildJobs)
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

			Write-Output -InputObject $outputStream
		}
}

Function ProcessRemotelyOutputToJSON {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Object[]]$InputObject,

        # Specify this switch to get the raw pester output back for the nodes.
        [Switch]$Raw  
    )
    foreach ($result in $InputObject) {
        $output = @{
            NodeName = $result.RemotelyTarget;
            Tests = if ($Raw.ISPresent) {@($result.TestResult)} else {GetFormattedTestResult -TestResult $result.TestResult};
            #Status = if ($result.FailedCount) {$False} else {$True};
        }
        $output | ConvertTo-Json -depth 100
    }

    
}

Function GetFormattedTestResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.ArrayList]$testResult  
    )
        $testsGroup = $testResult |Group-Object -Property Describe  
        foreach ($testGroup in $testsGroup) {
            $result = ($TestGroup.Group | select -ExpandProperty Passed ) -Notcontains $false
            $outputHash = @{
                Name = $testGroup.Name
                Result = $result
                TestResult =  $testGroup.Group | 
                                Where -Property Result -eq 'Failed' |
                                Select -Property Describe, Context, Name, Result, ErrorRecord
                }
            }
            Write-Output -InputObject $outputHash
}