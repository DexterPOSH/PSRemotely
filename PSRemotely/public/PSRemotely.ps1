function PSRemotely
{
<#
	.SYNOPSIS
	Provides a Keyword to wrap around the existing Ops validation tests.

	.PARAMETER Body 
	Scriptblock enclosing the Node block to target the remote ops validation at.

	.PARAMETER ConfigurationData
	Provide DSC style ConfigurationData for environment details to PSRemotely.
	
	.PARAMETER Path
	The ConfigurationData can be supplied via a .psd1 or .json file.
	PSRemotely will be able to work with all these configuration data sources, until it follows the DSC syntax for it.
	
	.PARAMETER ArgumentList
	Key-Value pairs corresponding to variable-value which are passed to and made available on all the remote nodes.
	This might be useful if you need a variable across on all nodes while executing ops validation tests.

	.PARAMETER CredentialHash
	Specify a hash with node name as key and credential object as value. PSRemotely will use this to open a PSSession
	to the nodes.
	
	$CredHashTable = @{
		'Compute-11'= $(Import-CliXML -Path .\Compute_Cred.xml);
		'Storage-12'= $(Get-Credential)
	}

	.NOTES
	Read the documentation hosted on GitHub for the project for using the DSL.
	
	.LINK
	Node
	Invoke-PSRemotely

#>
	[OutputType([String[]])]
	[CmdletBinding(DefaultParameterSetName='ConfigurationData')]
    param 
    (       
        [Parameter(Mandatory = $true, Position = 0)]
        [ScriptBlock] $body,

		[Parameter(Position = 1,
					ParameterSetName='ConfigurationData')]
        [hashtable] $configurationData,
		
		[Parameter(Position=1, ParameterSetName='ConfigDataFromFile')]
		[ValidateScript({ '.json','.psd1'  -contains $([System.IO.Path]::GetExtension($_))})] 
		[ValidateScript({Test-Path -Path $_})]
		[String]$Path,

		# Key-Value pairs corresponding to variable-value which are passed to the PSRemotely node.
        [Parameter(Mandatory = $false, Position = 2)]
        [Hashtable]$argumentList,

		# Credentials in the node name - PSCredential Object (key-Value) pair.
        [Parameter(Mandatory = $false, Position = 3)]
		[hashtable]$credentialHash
    )
	BEGIN {
		TRY {
			# Add CredentialHash & ArgumentList in Script scope
			if ($credentialHash){
				Write-VerboseLog -Message 'Setting CredentialHash passed in Script scope'
				Set-Variable -Name CredentialHash  -Scope  Script
			}

			if ($argumentList){
				Write-VerboseLog -Message 'Setting ArgumentList passed in Script scope'
				Set-Variable -Name ArgumentList  -Scope  Script -Value $ArgumentList
			}
			else {
				Write-VerboseLog -Message 'Creating an empty Argumnelist variable in Script scope'
				New-Variable -Name ArgumentList -Scope Script -Value @{} -Force -ErrorAction SilentlyContinue
			}
			
			Switch -Exact ($PSCmdlet.ParameterSetName) {
				'ConfigurationData' {
					Write-VerboseLog -Message 'ParameterSet - ConfigurationData'
					break
				}
				'ConfigDataFromFile' {
					Write-VerboseLog -Message 'ParameterSet - ConfigDataFromFile'
					$ConfigurationData = LoadConfigDataFromFile -Path $Path
					break
				}
			}
			
			#region create the PSSessions & bootstrap nodes	  
			if ($ConfigurationData) {
				Write-VerboseLog -Message 'Configuration data supplied, processing now.'
				# validate the config data
				Write-VerboseLog -Message 'Testing the configuration data supplied.'
				Test-ConfigData -ConfigurationData $configurationData

				Write-VerboseLog -Message 'Updating the configuration data supplied'
				$configurationData = Update-ConfigData -ConfigurationData $configurationData

				# Define the AllNodes variable in current scope
				Write-VerboseLog -Message 'Creating the AllNodes global scope variable'
				New-Variable -Name AllNodes -Value $configurationData.AllNodes -Scope Global  -Force
				
				if ($AllNodes.NodeName) {
					Write-VerboseLog -Message 'Creating sessions'
					CreateSessions -ConfigData $configurationData -CredentialHash $CredentialHash  -ArgumentList $ArgumentList

					if( $PSRemotely.sessionHashTable.Values.count -le 0) {
						Write-VerboseLog -Message 'Error - No PSSessions opened'
						throw 'No sessions created'
					}
					else {
						Write-VerboseLog -Message 'PSSessions found open'
						foreach($sessionInfo in $PSRemotely.sessionHashTable.Values.GetEnumerator()) {
							Write-VerboseLog -Message "Checking and Reconnecting if needed for $($sessionInfo.Session.ComputerName)"
							CheckAndReConnect -sessionInfo $sessionInfo
							if(TestRemotelyNodeBootStrapped -SessionInfo $sessionInfo) {
								# In memory Node map, has the node marked as bootstrapped
								Write-VerboseLog -Message "$($sessionInfo.Session.Computername) is bootstrapped."
								# archive the existing tests files on the PSRemotely node
								Write-VerboseLog -Message "Cleaning up $($PSRemotely.PSRemotelyNodePath) on Node -> $($sessionInfo.Session.ComputerName)"
								CleanupPSRemotelyNodePath -Session $sessionInfo.session -PSRemotelyNodePath $PSRemotely.PSRemotelyNodePath
							}
							else {
								# run the bootstrap function
								Write-VerboseLog -Message "$($sessioninfo.Session.ComputerName) is NOT bootstrapped. Trying now."
								BootstrapRemotelyNode -Session $sessionInfo.Session -FullyQualifiedName $PSRemotely.modulesRequired -PSRemotelyNodePath $PSRemotely.PSRemotelyNodePath
							}
						}
					}
				}
			}
		} #end Try
		CATCH {
			Write-VerboseLog -ErrorInfo $PSitem
			$PSCmdlet.ThrowTerminatingError($PSitem)
		}
	} #end Begin
	PROCESS {
		
	}
	END {
		Write-VerboseLog -Message 'Invoking the body of PSRemotely'
		
		& $Body # invoke the body
		Write-VerboseLog -Message 'Clearing the AllNodes global variable'
		Remove-Variable -Name AllNodes -Scope Global -Force -ErrorAction SilentlyContinue
	
	}

}