Function Node {
    [OutputType([void])]
	[CmdletBinding()]
    param(
		[Parameter(Mandatory = $True,Position = 0,
					ValueFromPipeline = $True)]
		[String[]]$name,

		# The Pester Describe block which gets executed on the remotely node.
        [Parameter(Mandatory = $true, Position = 1)]
        [ScriptBlock] $testBlock,

		# Tag the nodes
		[Parameter()]
		[String[]]$Tag

    )
	BEGIN {
		if($Remotely.sessionHashTable.Count -ne 0) {
			$sessions = @()
			foreach($sessionInfo in $Remotely.sessionHashTable.Values.GetEnumerator())
			{
				$sessions += $sessionInfo.Session
			}
		}
		else {
			# this might mean that the Configuration data was never supplied
			# Check if the AllNodes Script var is present is not null
			if(-not $Global:AllNodes) {
				
				CreateSessions -Nodes $Name  -CredentialHash $CredentialHash  -ArgumentList $ArgumentList
				if( $Remotely.sessionHashTable.Values.count -le 0) {
					throw 'No sessions created'
				}
				else {
                    $sessions = @()
					foreach($sessionInfo in $Remotely.sessionHashTable.Values.GetEnumerator())
					{
						CheckAndReConnect -sessionInfo $sessionInfo
                        $sessions += $sessionInfo.Session
						if(TestRemotelyNodeBootStrapped -SessionInfo $sessionInfo) {
							# In memory Node map, has the node marked as bootstrapped
						}
						else {
							# run the bootstrap function
							BootstrapRemotelyNode -Session $sessionInfo.Session -FullyQualifiedName $Remotely.modulesRequired -RemotelyNodePath $Remotely.remotelyNodePath
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
			$testFileName = "{0}.{1}.Tests.ps1" -f $nodeName, $testName.replace(' ','_')
			# get the relevant Session for the node
			$session = $Sessions | Where-Object -FilterScript {$PSitem.ComputerName -eq $nodeName}

			# copy/overwrite the artefacts on the remotely nodes
			Copy-Item -Path "$PSScriptRoot\..\Lib\Artefacts" -Destination "$($Remotely.RemotelyNodePath)\Lib\Artefacts" -Recurse -ToSession $session  -Force

			# invoke the Pester tests
			$testjob += Invoke-Command -Session $session -ScriptBlock {
				param(
					[hashtable]$Remotely,
					[String]$testBlock,
					[String]$testFileName,
					[String]$nodeName,
					[String]$testName,
					[Object[]]$Script # Passed to Pester while invoking

				)
                $Remotely.modulesRequired | 
                Foreach {
					$moduleName = $PSitem.ModuleName
					$moduleVersion = $Psitem.ModuleVersion
                    Import-Module "$($Remotely.remotelyNodePath)\lib\$moduleName\$moduleVersion\$($ModuleName).psd1";
					Write-Verbose -Verbose -Message "Imported module $($PSitem.ModuleName) from remotely lib folder"
                }
				$testFile = "$($Remotely.remotelyNodePath)\$testFileName"
				$outPutFile = "{0}\{1}.{2}.xml" -f 	 $Remotely.remotelyNodePath, $nodeName, $testName
				if ($Node) { 
					# Check if the $Node var was populated in the remote session, then add param node to the test block
					$testBlock = $testBlock.Insert(0,'param($node)')
				}
				Set-Content -Path $testFile -Value $testBlock	-Force
				$pesterParams = @{}
				if ($Script) {
					$pesterParams.Add('Script',$Script)
				}

				# TODO check if Pester arguments are populated in as variables and use them there
				if($pesterParams.Count -ge 1) {
					Invoke-Pester @pesterParams -PassThru -Quiet -OutputFormat NUnitXML -OutputFile $outPutFile
				}
				else {
					if ($Node) {
						Invoke-Pester -Script @{Path=$($TestFile); Parameters=@{Node=$Node}} -PassThru -Quiet -OutputFormat NUnitXML -OutputFile $outPutFile
					}
					else {
						Invoke-Pester -Script $testFile  -PassThru -Quiet -OutputFormat NUnitXML -OutputFile $outPutFile
					}
					
				}
                
			} -ArgumentList $Remotely, $($testBlock.ToString()), $testFileName , $nodeName, $testName -AsJob 
		}
	}
	END {
		$null = $testjob | Wait-Job
		$results = @(ProcessRemotelyJobs -InputObject $TestJob)
        $testjob | Remove-Job -Force
	    ProcessRemotelyOutputToJSON -InputObject $results
    }

}