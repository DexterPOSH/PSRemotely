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
			
			# get the relevant Session for the node
			$session = $Sessions | Where-Object -FilterScript {$PSitem.ComputerName -eq $nodeName}

			# get the test name from the Describe block
			$testNameandTestBlockArray = @(Get-TestNameAndTestBlock -Content $testBlock) # this returns the Describe block name and the body as string
			
			#region copy the required tests file and artefacts

			foreach ($entry in $testNameandTestBlockArray) {
		
				# Copy each tests file to the remote node.
				CopyTestsFileToRemotelyNode -Session $session -TestName $entry.Keys -TestBlock $entry.Values
			}

			# copy/overwrite the artefacts on the remotely nodes
			Copy-Item -Path "$PSScriptRoot\..\Lib\Artefacts" -Destination "$($Remotely.RemotelyNodePath)\Lib\Artefacts" -Recurse -ToSession $session  -Force

			#endregion copy the required tests file and artefacts

	
			
			# invoke the Pester tests
			$testjob += Invoke-Command -Session $session -ScriptBlock {
				param(
					[hashtable]$Remotely,
					[String]$nodeName
				)
                $Remotely.modulesRequired | 
                Foreach {
					$moduleName = $PSitem.ModuleName
					$moduleVersion = $Psitem.ModuleVersion
                    Import-Module "$($Remotely.remotelyNodePath)\lib\$moduleName\$moduleVersion\$($ModuleName).psd1";
					Write-Verbose -Verbose -Message "Imported module $($PSitem.ModuleName) from remotely lib folder"
                }
				$nodeoutputFile = "{0}.xml}" -f $nodeName
				# invoke pester now to run all the tests
				if ($Node) {
						Invoke-Pester -Script @{Path="$($Remotely.remotelyNodePath)\*.tests.ps1"; Parameters=@{Node=$Node}} -PassThru -Quiet -OutputFormat NUnitXML -OutputFile $nodeoutputFile
					}
					else {
						Invoke-Pester -Script "$($Remotely.remotelyNodePath)\*.tests.ps1"  -PassThru -Quiet -OutputFormat NUnitXML -OutputFile $nodeoutputFile
					}
			} -ArgumentList $Remotely, $nodeName -AsJob 
		}
	}
	END {
		$null = $testjob | Wait-Job
		$results = @(ProcessRemotelyJobs -InputObject $TestJob)
        $testjob | Remove-Job -Force
	    ProcessRemotelyOutputToJSON -InputObject $results
    }

}