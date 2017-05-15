Function ProcessRemotelyJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Collections.DictionaryEntry]$InputObject  
    )
    $NodeName = $InputObject.Key
    $Job = $InputObject.Value
    foreach($childJob in $Job.ChildJobs){
        if($childJob.Output.Count -eq 0){
            [object] $outputStream = New-Object psobject
        }
        else {
            
            [object] $outputStream = $childJob.Output | Foreach-Object -Process { $_ }
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
        #Write-Host -Object "$($outputStream.RemotelyTarget) NodeName -> $NodeName" -ForegroundColor red
        $outputStream = Add-Member -InputObject $outputStream -PassThru -MemberType NoteProperty -Name __Streams -Value $allStreams
        $outputStream = Add-Member -InputObject $outputStream -PassThru -MemberType ScriptMethod -Name GetError -Value { return $this.__Streams.Error }
        $outputStream = Add-Member -InputObject $outputStream -PassThru -MemberType ScriptMethod -Name GetVerbose -Value { return $this.__Streams.Verbose }
        $outputStream = Add-Member -InputObject $outputStream -PassThru -MemberType ScriptMethod -Name GetDebugOutput -Value { return $this.__Streams.DebugOutput }
        $outputStream = Add-Member -InputObject $outputStream -PassThru -MemberType ScriptMethod -Name GetProgressOutput -Value { return $this.__Streams.ProgressOutput }
        $outputStream = Add-Member -InputObject $outputStream -PassThru -MemberType ScriptMethod -Name GetWarning -Value { return $this.__Streams.Warning }
        $outputStream = Add-Member -InputObject $outputStream -PassThru -MemberType NoteProperty -Name RemotelyTarget -Value $NodeName

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
    $NodeName = $InputObject.RemotelyTarget | Select-Object -Unique
    $NodeName = $NodeName -replace '\[',''
    $NodeName = $NodeName -replace '\]',''
    $output = @{
        NodeName = $NodeName;
        Tests = @( if ($Raw.ISPresent) {
                        $InputObject.TestResult
                    } 
                    else {
                        GetFormattedTestResult -TestResult $InputObject.TestResult
                    })
        #Status = if ($result.FailedCount) {$False} else {$True};
    }

    $output.Add('Status',$(@($output.Tests.GetEnumerator() | Foreach-Object -Process {$PSItem.Result}) -notcontains $false ))
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
            $result = ($TestGroup.Group | Select-Object -ExpandProperty Passed ) -Notcontains $false
            $outputHashArray += @{
                Name = $testGroup.Name
                Result = $result
                TestResult =  @($testGroup.Group | 
                                Where-Object -Property Result -eq 'Failed' |
                                Select-Object -Property Describe, Context, Name, Result, ErrorRecord)
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
        [Hashtable]$inputObject
    )
    TRY {
        $AllJobsCompletedHash = @{}

        $inputObject.Keys | Foreach-Object -Process {
            $AllJobsCompletedHash.Add($PSItem, $False)
        }

        do {
            $CloneJobHash = $AllJobsCompletedHash.Clone() # used to iterate over the Hashtable
            foreach ($nodeJobStatus in $CloneJobHash.GetEnumerator()) {
                Write-VerboseLog -Message "Processing for Node -> $($nodeJobStatus.key) "
                if ($nodeJobStatus.Value) {
                    # node job status is True, it has been processed
                    Write-VerboseLog -Message "PSRemotely job already processed for Node -> $($nodeJobStatus.key) "
                }
                else {
                    # node job status is False, it has not been processed
                    # Process the job now
                    $enum = $inputObject.GetEnumerator() | 
                            Where-Object -FilterScript {$PSItem.Key -eq $nodeJobStatus.Key}

                    if ($enum.Value | Where-Object -Property State -In @('Completed', 'Failed')) {
                        Write-VerboseLog -Message "PSRemotely job finished for Node -> $($nodeJobStatus.key). Processing it now."
                        $enum | ProcessRemotelyJob | ProcessRemotelyOutputToJSON
                        $AllJobsCompletedHash[$enum.key] = $true
                    }
                    
                }
            }

        }  until (@($allJobsCompletedHash.Values) -notcontains $False)
    }
    CATCH {
        Write-VerboseLog -ErrorInfo $PSitem
        $PSCmdlet.ThrowTerminatingError($_)        
    }
    
}
