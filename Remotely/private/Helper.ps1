Function ProcessRemotelyJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object]$InputObject  
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
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object]$InputObject,

        # Specify this switch to get the raw pester output back for the nodes.
        [Switch]$Raw  
    )
    
    $output = @{
        NodeName = $InputObject.RemotelyTarget;
        Tests = @( if ($Raw.ISPresent) {
                        $InputObject.TestResult
                    } 
                    else {
                        GetFormattedTestResult -TestResult $InputObject.TestResult
                    })
        #Status = if ($result.FailedCount) {$False} else {$True};
    }

    $output.Add('Status',$(@($output.Tests.GetEnumerator() | Foreach {$PSItem.Result}) -notcontains $false ))
    $output | ConvertTo-Json -depth 100

    
}

Function GetFormattedTestResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.ArrayList]$testResult  
    )
        $outputHashArray = @()
        $testsGroup = $testResult |Group-Object -Property Describe  
        foreach ($testGroup in $testsGroup) {
            $result = ($TestGroup.Group | select -ExpandProperty Passed ) -Notcontains $false
            $outputHashArray += @{
                Name = $testGroup.Name
                Result = $result
                TestResult =  @($testGroup.Group | 
                                Where -Property Result -eq 'Failed' |
                                Select -Property Describe, Context, Name, Result, ErrorRecord)
                }
            }
            Write-Output -InputObject $outputHashArray
}

Function Write-VerboseLog
{

    [CmdletBinding(DefaultParameterSetName='Message')]
    Param
    (
        # Message to be written to the Verbose Stream
        [Parameter(ParameterSetName ='Message',
                        Position=0,
                        ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]        
        [System.String]$Message,

        # In case of calling this from Catch block pass the Invocation info
        [Parameter(ParameterSetName='Error',
                    ValueFromPipeline,
                    ValueFromPipelineByPropertyName)]
        [System.Management.Automation.ErrorRecord]$ErrorInfo
    )
    switch -exact ($PSCmdlet.ParameterSetName) {       
        'Message' {    
            $parentcallstack = (Get-PSCallStack)[1] # store the parent Call Stack        
            $Functionname = $parentcallstack.FunctionName
            $LineNo = $parentcallstack.ScriptLineNumber
            $scriptname = ($parentcallstack.Location -split ':')[0]
            Write-Verbose -Message "$scriptname - $Functionname - LineNo : $LineNo - $Message"    
        }
        'Error' {
            # In case of error, Error Record is passed and we use that to write key info to verbose stream
            $Message = $ErrorInfo.Exception.Message
            $Functionname = $ErrorInfo.InvocationInfo.InvocationName
            $LineNo = $ErrorInfo.InvocationInfo.ScriptLineNumber
            $scriptname = $(Split-Path -Path $ErrorInfo.InvocationInfo.ScriptName -Leaf)
            Write-Verbose -Message "$scriptname - $Functionname - LineNo : $LineNo - $Message"           
            #$PSCmdlet.ThrowTerminatingError($ErrorInfo)
            #Write-Error -ErrorRecord $ErrorInfo -ErrorAction Stop # throw back the Error record 
        }
    }   
}

Function Start-RemotelyJobProcessing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Object[]]$inputObject
    )
    TRY {
        $allJobsCompletedHash = @{}

        $inputObject | Foreach-Object -Process {
            $allJobsCompletedHash.Add($PSItem, $false)
        }

        $cloneJobHash = $allJobsCompletedHash.Clone()

        do {

            foreach ($enum in $cloneJobHash.GetEnumerator()) {

                if ($allJobsCompletedHash[$enum.key]) {
                    # means job was processed
                    Write-VerboseLog -Message "Remotely job already processed for Node -> $(($enum.key).Location )"
                }
                else {
                    # see if the job finished
                    if ($enum.Key | Where -Property State -In @('Completed','Failed')) {
                        Write-VerboseLog -Message "Remotely job completed/failed for Node -> $(($enum.key).Location ) . Processing it now."
                        $enum.Key | ProcessRemotelyJob | ProcessRemotelyOutputToJSOn
                        $allJobsCompletedHash[$enum.key] = $true # set the job processed status to True
                    }
                }   
            }
        
            # induce delay of 2 seconds
            Write-VerboseLog -Message 'Remotely jobs still running, sleep for 5 seconds'
            Start-Sleep -Seconds 5

        } until (@($allJobsCompletedHash.Values) -notcontains $False)
    }
    CATCH {
        Write-VerboseLog -ErrorInfo $PSitem
        $PSCmdlet.ThrowTerminatingError($_)        
    }
    
}
