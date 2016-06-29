function Remotely
{
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
	# Add CredentialHash & ArgumentList in Script scope
	if ($credentialHash){
		Set-Variable -Name CredentialHash  -Scope  Script
	}

	if ($argumentList){
		Set-Variable -Name ArgumentList  -Scope  Script
	}
	else {
		New-Variable -Name ArgumentList -Scope Script -Value @{} -Force -ErrorAction SilentlyContinue
	}
	
	Switch -Exact ($PSCmdlet.ParameterSetName) {
		'ConfigurationData' {
			break
		}
		'ConfigDataFromFile' {
			$ConfigurationData = LoadConfigDataFromFile -Path $Path
			break
		}
	}
	
	#region create the PSSessions & bootstrap nodes	  
	if ($ConfigurationData) {
		# validate the config data
		Test-ConfigData -ConfigurationData $configurationData

		$configurationData = Update-ConfigData -ConfigurationData $configurationData

		# Define the AllNodes variable in current scope
		New-Variable -Name AllNodes -Value $configurationData.AllNodes -Scope  Global -Force
	 	
		if ($Global:AllNodes.NodeName) {
			CreateSessions -ConfigData $configurationData -CredentialHash $CredentialHash  -ArgumentList $ArgumentList

			if( $Remotely.sessionHashTable.Values.count -le 0) {
				throw 'No sessions created'
			}
			else {
				foreach($sessionInfo in $Remotely.sessionHashTable.Values.GetEnumerator())
					{
						CheckAndReConnect -sessionInfo $sessionInfo
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
	}
	PROCESS {
		
	}
	END {
		& $Body # invoke the body
		Remove-Variable -Name AllNodes -Scope Global -Force -ErrorAction SilentlyContinue
	}
	
	

}