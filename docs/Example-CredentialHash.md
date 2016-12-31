# PSRemotely example passing credential hashtable

Since PSRemotely utilizes PSSession opened to the remote nodes to bootstrap them and run tests.
Sometimes you might have different set of credentials for different nodes.

One of the ways to do that is by specifying the credentials to be used to connect to the remote nodes
in a hashtable format with node name as the key and credential object as the value.

```powershell
$CredHashTable = @{
    'Compute-11'= $(Import-CliXML -Path .\Compute_Cred.xml);
    'Storage-12'= $(Get-Credential)
}
```

See above that it solely depends on how you create the credential object and pass it to the hashtable.
Once you have the credential hashtable ready for the nodes, you can supply that as one of the parameters
to you PSRemotely file.

Below is how CredentialHash.PSRemotely.ps1 looks like :

```powershell
param($CredentialHash)

# Remotely tests
Remotely -credentialHash $CredentialHash {
	Node "Compute-11","Storage-12" {
		Describe 'Bits Service test' {
			
			$Service = Get-Service -Name 'bits'
			
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

Now invoking the PSRemotely for the remote ops validation is done by using Invoke-PSRemotely :-

```powershell
Invoke-PSRemotely -Script @{
    Path="<Path to the CredentialHash.PSRemotely.ps1>";
    Parameters=@{CredentialHash=$CredHashTable}
}
```

P.S. - In the above example, the configuration data is not used but you can defintely use both 
configuration data and credential hash in conjunction with PSRemotely.