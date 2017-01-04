# TroubleShoot

So you have your tests in place in the .PSRemotely.ps1 files and you invoked them using Invoke-PSRemotely.
Now things do not always go the way you assumed. The most common issues seen with using PSRemotely to orchestrate the operations 
validation on the remote nodes is that the tests failed and you want to connect to the remote node and want to see for yourself.

So suppose you have below operations validations tests for few nodes in a .PSRemotely.ps1 file :

```powershell
# Configuration Data
$ConfigData = @{
	AllNodes = @(
		@{
			NodeName='*';
			DomainFQDN='dexter.lab';
		},
		@{
			NodeName="ComputeNode1";
			ServiceName = 'bits';
			Type='Compute';

		},
		@{
			NodeName='StorageNode1';
			ServiceName = 'winrm';
			Type='Storage';
		}
	)
}

# PSRemotely tests
PSRemotely -ConfigurationData $ConfigData {
	Node $AllNodes.Where({$PSItem.Type -eq 'Compute'}).NodeName {
		Describe 'Bits Service test' {
			
			$Service = Get-Service -Name $ServiceName # Typo here
			
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

You invoked the tests using *Invoke-PSRemotely* and found out the test were failing on the *ComputeNode1* and you see below output :

Now to see what went wrong in the underlying PSSession where the $Node variable was defined and Pester was invoked.
You can drop into it by using the below

```powershell
Enter-PSSession -Session $PSRemotely.SessionHashTable['ComputeNode1'].Session
```

Once you are connected to the remote PSSession then you can invoke the tests by traversing to the 
PSRemotelyNodePath ($PSRemotely is made available in the Remote PSSession too)

```powershell
# traverse to the remotely node path
Cd $PSRemotely.PSRemotelyNodePath
# Check the $Node in the underlying PSSession
$Node
# Invoke Pester and see for yourself, what could be the issue.
Invoke-Pester
```