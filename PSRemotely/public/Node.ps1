Function Node {
<#
	.SYNOPSIS
	Function implementing the 'Node' keyword logic.
	The Node keyword targets the remote nodes by bootstrapping the nodes and  getting them ready for PSRemotely.

	.PARAMETER Name 
	DNS name of the remote name to target for the Remote ops validation.

	.PARAMETER testBlock
	 Scriptblock housing various Pester Describe block which gets executed on the remote node by PSRemotely.
	
	.PARAMETER Tag
	Specify the tag which gets passed to Pester while running tests on the remote nodes.
	This lets you have multiple Node blocks for the same node but lets Remotely know that you intend to
	run Pester tests with a specific tag.

	.NOTES
	Read the documentation hosted on GitHub for the project for using the DSL.
	
	.LINK
	PSRemotely
	Invoke-PSRemotely

#>
    [OutputType([String[]])]
	[CmdletBinding()]
    param(
		[Parameter(Mandatory = $True,Position = 0,
					ValueFromPipeline = $True)]
		[String[]]$name,

        [Parameter(Mandatory = $true, Position = 1)]
        [ScriptBlock] $testBlock,

		# Tag the nodes
		[Parameter()]
		[String[]]$Tag

    )
	BEGIN {
		TRY {
			Write-VerboseLog -Message 'Begin Node Processing'
			if($PSRemotely.sessionHashTable.Count -ne 0) {
				$sessions = Get-RemoteSession
				Write-VerboseLog -Message "found sessions in SessionHashTable "
			}
			else {
				Write-VerboseLog -Message "No sessions found in SessionHashTable"
				# this might mean that the Configuration data was never supplied
				# Check if the AllNodes Script var is present is not null
				if(-not $AllNodes) {
					Write-VerboseLog -Message "AllNodes variable is not created. Implies configuration data was not supplied"
					Write-VerboseLog -Message "Creating sessions"
					CreateSessions -Nodes $Name  -CredentialHash $CredentialHash  -ArgumentList $ArgumentList
					if( $PSRemotely.sessionHashTable.Values.count -le 0) {
						Write-VerboseLog -Message 'Error - No PSSessions opened'
						throw 'No sessions created'
					}
					else {
						Write-VerboseLog -Message 'PSSessions found open'
						foreach($sessionInfo in $PSRemotely.sessionHashTable.Values.GetEnumerator())
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
								BootstrapRemotelyNode -Session $sessionInfo.Session -FullyQualifiedName $PSRemotely.modulesRequired -PSRemotelyNodePath $PSRemotely.PSRemotelyNodePath
							}
						}
						$sessions = Get-RemoteSession
					}
				}
			}
			$testjobHash = @{}
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
				$session = $Sessions | Where-Object -FilterScript {$PSitem.Name -like "*$nodeName*"} # Note -like "*$nodeName*" added because configdata may use IPv6 address
				# If Ipv6Address is used to connect to the PSRemotely node then the [,] braces are added to the computername property to the session object

				if ($session) {
					Write-VerboseLog -Message "PSSession for $nodeName found."
					# get the test name from the Describe block
					Write-VerboseLog -Message "Fetching the test name & test block targeted at Node -> $nodeName"
					$testNameandTestBlockArray = @(Get-TestNameAndTestBlock -Content $testBlock) # this returns the Describe block name and the body as string
					
					#region copy the required tests file and Artifacts
					Write-VerboseLog -Message "Copying tests file to the Node -> $nodeName"
					$testNameandTestBlockArray | Foreach-Object -Process {
						# Copy each tests file to the remote node.
						Write-VerboseLog -Message "Copying test named $($PSitem.Keys -join ' ') on Node -> $nodeName"
						CopyTestsFileToRemotelyNode -Session $session -NodeName $nodeName -TestName $PSItem.Keys -TestBlock $PSItem.Values
					}

					# copy/overwrite the Artifacts on the PSRemotely nodes
					# TODO - Read the Artifacts required from the $PSRemotely before copying them
					Write-VerboseLog -Message "Copying required Artifacts on Node -> $nodeName"
					Get-ChildItem -Path "$PSScriptRoot\..\Lib\Artifacts\*" -Recurse -ErrorAction SilentlyContinue | Where-Object -Filter {
						@($PSRemotely.ArtifactsRequired) -contains $PSItem.Name } |
						Foreach-Object -Process {
							Copy-Item -Path $PSItem.FullName -Destination "$($PSRemotely.PSRemotelyNodePath)\Lib\Artifacts" -Force -Recurse -ToSession $session
						}
					#endregion copy the required tests file and Artifacts
					
					# invoke the Pester tests
					Write-VerboseLog -Message "Setting up Node -> $nodeName. Done, Invoke the full test suite now."
					$job = Invoke-Command -Session $session -ScriptBlock {
						param(
							[string]$NodeName,
							[hashtable]$PSRemotely,
							[string[]]$tag
						)
						$PSRemotely.modulesRequired | 
						Foreach-Object {
							$moduleName = $PSitem.ModuleName
							$moduleVersion = $Psitem.ModuleVersion
							Import-Module "$($PSRemotely.PSRemotelyNodePath)\lib\$moduleName\$moduleVersion\$($ModuleName).psd1";
							Write-Verbose -Verbose -Message "Imported module $($PSitem.ModuleName) from PSRemotely lib folder"
						}
						if ($NodeName) {
							# if the nodename was supplied (this will always be supplied)
							$OutputFileName = '{0}.xml' -f $($NodeName);
							$IndexOfInvalidChar = $OutputFileName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars())
							# IndexOfAny() returns the value -1 to indicate no such character was found
							if($IndexOfInvalidChar -ne -1){
								# if there is an invalid character in the filename, fall back to using the computername
								Write-Warning -Message "Invalid character found in the file name > $($OutputFile). Switching to using env:computername for filename"
								$OutputFileName = "{0}.xml" -f $env:COMPUTERNAME
							}
						}
						else {
							$OutputFileName = '{0}.xml' -f $env:COMPUTERNAME;
						}
						 # generate the file path
						$OutputFile = "{0}\{1}" -f $($PSRemotely.PSRemotelyNodePath), $OutputFileName
						$invokePesterParams = @{
							PassThru = $True;
							Quiet = $True;
							OutputFormat = 'NunitXML';
							OutputFile = $OutputFile
						}

						# invoke pester now to run all the tests
						if ($Tag) {
							# Add the tag
							$invokePesterParams.Add('Tag', $Tag) 
						}
						Write-Verbose -Verbose -Message  "Invoking Pester with arguments $($invokePesterParams.GetEnumerator() | Foreach-Object {$_.Key, $_.Value})"
						if ($Node) {
								Invoke-Pester -Script @{Path="$($PSRemotely.PSRemotelyNodePath)\*.tests.ps1"; Parameters=@{Node=$Node}} @invokePesterParams
							}
							else {
								Invoke-Pester -Script "$($PSRemotely.PSRemotelyNodePath)\*.tests.ps1" @invokePesterParams
							}
					} -ArgumentList $NodeName,$PSRemotely, $Tag -AsJob 

					# Add the nodename and Job object to the hash, used further for the processing the output
					$testjobHash.Add($nodeName, $job)
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
		Write-VerboseLog -Message "Start background processing of the PSRemotely jobs."
		Start-RemotelyJobProcessing -InputObject $testJobHash
    }

}