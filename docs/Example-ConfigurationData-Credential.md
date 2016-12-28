# PSRemotely example passing credential in Configuration data

Since PSRemotely allows to use DSC style Configuration data for specifying environment details,
It also supports passing credential with a caveat.

If you specify the Credential attribute in the Configuration data for a Node, then those credentials
are given preference over other credentials supplied (e.g CredentialHash) to open a PSSession to the 
Remote node.

After opening a PSSession to the Remote node, the credentials are removed from the node Configuration data.
Since node specific Configuration data is made available on the underlying PSSession, this did not make sense.

Bottom line is credential attribute is Configuration data is used to open underlying PSSession which
PSRemotely uses.

Below is a sample Credential_with_ConfigData.PSRemotely.ps1 file :-

```powershell
param($ComputeCredential,$StorageCredential)

$ConfigData = @{
	AllNodes = @(
		@{
			NodeName='*';
			DomainFQDN='dexter.lab';
		},
		@{
			NodeName="Compute-11";
			ServiceName = 'vmms';
			Type='Compute';
            Credential=$ComputeCredential;
		},
		@{
			NodeName='Storage-12';
			ServiceName = 'bits';
			Type='Storage';
            Credential=$StorageCredential
		}
	)
}

# Remotely tests
Remotely -ConfigurationData $ConfigData {
	Node $AllNodes.Where({$PSItem.Type -eq 'Compute'}).NodeName {
		Describe 'Bits Service test' {
			
			$Service = Get-Service -Name $node.ServiceName # See the use of $node variable here
			
			It "Should have a service named bits" {
				$Service | Should Not BeNullOrEmpty
			}
			
			it 'Should be running' {
				$Service.Status | Should be 'Running'
			}
		}		
	}
}
```

Now invoking PSRemotely to run ops validation on the remote nodes by supplying different set of credentials
for different nodes in configuration data is done by using the below :-

```powershell
Invoke-PSRemotely -Script @{
    Path="<Path to the Credential_with_ConfigData.PSRemotely.ps1>";
    Parameters = @{
        ComputeCredential = $(Get-Credential -Message 'Enter Compute node creds');
        StorageCredential = $(Get-Credential -Message 'Enter Storage node creds');
    }
}
```