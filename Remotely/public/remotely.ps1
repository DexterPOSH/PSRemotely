function Remotely
{
	[OutputType([String[]])]
	[CmdletBinding(DefaultParameterSetName='ConfigurationData')]
    param 
    (       
        # The body script block.
        [Parameter(Mandatory = $true, Position = 0)]
        [ScriptBlock] $body,

		# DSC style configuration data , follows the same syntax
		[Parameter(Position = 1,
					ParameterSetName='ConfigurationData')]
        [hashtable] $configurationData,
		
		# Specify the path to a file (.json or .psd1) which houses the configuration data
		[Parameter(Position=2, ParameterSetName='ConfigDataFromFile')]
		[ValidateScript({ '.json','.psd1'  -contains $([System.IO.Path]::GetExtension($_))})] 
		[ValidateScript({Test-Path -Path $_})]
		[String]$Path,

		# Key-Value pairs corresponding to variable-value which are passed to the remotely node.
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
				Set-Variable -Name ArgumentList  -Scope  Script
			}
			else {
				Write-VerboseLog -Message 'Creating an emtyp Argumnelist variable in Script scope'
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
				New-Variable -Name AllNodes -Value $configurationData.AllNodes -Scope  Global -Force
				
				if ($Global:AllNodes.NodeName) {
					Write-VerboseLog -Message 'Creating sessions'
					CreateSessions -ConfigData $configurationData -CredentialHash $CredentialHash  -ArgumentList $ArgumentList

					if( $Remotely.sessionHashTable.Values.count -le 0) {
						Write-VerboseLog -Message 'Error - No PSSessions opened'
						throw 'No sessions created'
					}
					else {
						Write-VerboseLog -Message 'PSSessions found open'
						foreach($sessionInfo in $Remotely.sessionHashTable.Values.GetEnumerator()) {
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
		Write-VerboseLog -Message 'Invoking the body of Remotely'
		& $Body # invoke the body
		Write-VerboseLog -Message 'Clearing the AllNodes global variable'
		Remove-Variable -Name AllNodes -Scope Global -Force -ErrorAction SilentlyContinue
	
	}

}