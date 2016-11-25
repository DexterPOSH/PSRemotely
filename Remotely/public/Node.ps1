Function Node {
    [OutputType([String[]])]
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
		TRY {
			Write-VerboseLog -Message 'Begin Node Processing'
			if($Remotely.sessionHashTable.Count -ne 0) {
				$sessions = Get-RemoteSession
				Write-VerboseLog -Message "found sessions in SessionHashTable "
			}
			else {
				Write-VerboseLog -Message "No sessions found in SessionHashTable"
				# this might mean that the Configuration data was never supplied
				# Check if the AllNodes Script var is present is not null
				if(-not $Global:AllNodes) {
					Write-VerboseLog -Message "AllNodes variable is not created. Implies configuration data was not supplied"
					Write-VerboseLog -Message "Creating sessions"
					CreateSessions -Nodes $Name  -CredentialHash $CredentialHash  -ArgumentList $ArgumentList
					if( $Remotely.sessionHashTable.Values.count -le 0) {
						Write-VerboseLog -Message 'Error - No PSSessions opened'
						throw 'No sessions created'
					}
					else {
						Write-VerboseLog -Message 'PSSessions found open'
						foreach($sessionInfo in $Remotely.sessionHashTable.Values.GetEnumerator())
						{
							Write-VerboseLog -Message "Checking and Reconnecting if needed for $($sessionInfo.Session.ComputerName)"
							CheckAndReConnect -sessionInfo $sessionInfo
							if(TestRemotelyNodeBootStrapped -SessionInfo $sessionInfo) {
								# In memory Node map, has the node marked as bootstrapped
								Write-VerboseLog -Message "$($sessionInfo.Session.Computername) is bootstrapped."
							}
							else {
								# run the bootstrap function
								Write-VerboseLog -Message "$($sessioninfo.Session.ComputerName) is NOT bootstrapped. Trying now."
								BootstrapRemotelyNode -Session $sessionInfo.Session -FullyQualifiedName $Remotely.modulesRequired -RemotelyNodePath $Remotely.remotelyNodePath
							}
						}
						$sessions = Get-RemoteSession
					}
				}
			}
			$testjob = @()
		} # end Try
		CATCH {
			Write-VerboseLog -ErrorInfo $PSitem
			$PSCmdlet.ThrowTerminatingError($PSitem)	
		}
	}
	PROCESS {

		foreach($nodeName in $name)  {
			TRY {
				Write-VerboseLog -Message "Setting up Node -> $nodeName for tests execution"
				# get the relevant Session for the node
				$session = $Sessions | Where-Object -FilterScript {$PSitem.ComputerName -like "*$nodeName*"} # Note -like "*$nodeName*" added because configdata may use IPv6 address
				# If Ipv6Address is used to connect to the remotely node then the [,] braces are added to the computername property to the session object

				if ($session) {
					Write-VerboseLog -Message "PSSession for $nodeName found."
					# get the test name from the Describe block
					Write-VerboseLog -Message "Fetching the test name & test block targeted at Node -> $nodeName"
					$testNameandTestBlockArray = @(Get-TestNameAndTestBlock -Content $testBlock) # this returns the Describe block name and the body as string
					
					#region copy the required tests file and artefacts
					Write-VerboseLog -Message "Copying tests file to the Node -> $nodeName"
					$testNameandTestBlockArray | Foreach-Object -Process {
						# Copy each tests file to the remote node.
						Write-VerboseLog -Message "Copying test named $($PSitem.Keys -join ' ') on Node -> $nodeName"
						CopyTestsFileToRemotelyNode -Session $session -TestName $PSItem.Keys -TestBlock $PSItem.Values
					}

					# copy/overwrite the artefacts on the remotely nodes
					# TODO - Read the artefacts required from the $Remotely before copying them
					Write-VerboseLog -Message "Copying required artefacts on Node -> $nodeName"
					Get-ChildItem -Path "$PSScriptRoot\..\Lib\Artefacts\*" -Recurse | Where-Object -Filter {
						@($Remotely.ArtefactsRequired) -contains $PSItem.Name } |
						Foreach-Object -Process {
							Copy-Item -Path $PSItem.FullName -Destination "$($Remotely.RemotelyNodePath)\Lib\Artefacts" -Force -Recurse -ToSession $session
						}
					#endregion copy the required tests file and artefacts
					
					# invoke the Pester tests
					Write-VerboseLog -Message "Setting up Node -> $nodeName. Done, Invoke the full test suite now."
					$testjob += Invoke-Command -Session $session -ScriptBlock {
						param(
							[hashtable]$Remotely,
							[string[]]$tag
						)
						$Remotely.modulesRequired | 
						Foreach {
							$moduleName = $PSitem.ModuleName
							$moduleVersion = $Psitem.ModuleVersion
							Import-Module "$($Remotely.remotelyNodePath)\lib\$moduleName\$moduleVersion\$($ModuleName).psd1";
							Write-Verbose -Verbose -Message "Imported module $($PSitem.ModuleName) from remotely lib folder"
						}
						#$nodeOutputFile = "{0}\{1}.xml" -f $($Remotely.remotelyNodePath), $Env:ComputerName
						$invokePesterParams = @{
							PassThru = $True;
							Quiet = $True;
							OutputFormat = 'NunitXML';
							OutputFile = '{0}\{1}.xml' -f $($Remotely.remotelyNodePath), $Env:ComputerName;
						}
						# invoke pester now to run all the tests
						if ($Tag) {
							# Add the tag
							$invokePesterParams.Add('Tag', $Tag) 
						}
						Write-Verbose -Verbose -Message  "Invoking Pester with arguments $($invokePesterParams.GetEnumerator() | % {$_.Key, $_.Value})"
						if ($Node) {
								Invoke-Pester -Script @{Path="$($Remotely.remotelyNodePath)\*.tests.ps1"; Parameters=@{Node=$Node}} @invokePesterParams
							}
							else {
								Invoke-Pester -Script "$($Remotely.remotelyNodePath)\*.tests.ps1" @invokePesterParams
							}
					} -ArgumentList $Remotely, $Tag -AsJob 
				}
				else {
					Write-Warning -Message "PSSession for $nodeName NOT found."
					Write-VerboseLog -Message "PSSession for $nodeName NOT found."			
				}
			} # end TRY
			CATCH {
				Write-VerboseLog -ErrorInfo $PSitem
				Write-Warning -Message "Setting up Node -> $nodeName , and running tests failed"
				#$PSCmdlet.ThrowTerminatingError($PSitem)
			}
		}
	}
	END {
		#$null = $testjob | Wait-Job
		#$results = @(ProcessRemotelyJobs -InputObject $TestJob)
        #$testjob | Remove-Job -Force
	    #ProcessRemotelyOutputToJSON -InputObject $results

		# Process background jobs as they are finished, rather than waiting for all of them to finish
		Write-VerboseLog -Message "Start background processing of the Remotely jobs."
		Start-RemotelyJobProcessing -InputObject $testJob
    }

}