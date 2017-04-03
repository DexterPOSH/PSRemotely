# PSRemotely example using IPv4 address for targeting remote nodes.

PSRemotely allows usage of IPv4 addresses for targeting operations validation to them.
The only gotcha is that, the machine where the PSRemotely will run should be configured to connect using IPv4 address to the remote node.
This typically requires configuring the TrustedHosts for the local winrm client.

Note that if you are using IPv4 address then you have to explicitly specify the credentials to be used to connect to the remote node.
PSRemotely allows two different approaches for specifying the credential.

- [Using Credential hash](http://psremotely.readthedocs.io/en/latest/Example-CredentialHash/)
- [Specifying Credential in the Configuration data](http://psremotely.readthedocs.io/en/latest/Example-ConfigurationData-Credential/)


## Example - specifying credential in the configuration data along with IPv4 address as the node name
Below is an example showing how to specify the credential to be used to connect to the Remote node.
Note - The credential to be used must be named 'Credential' only in the node configuration data.

```powershell
$configdata = @{
    AllNodes = @(
        @{
            # common node information hashtable
            NodeName = '*';
            DomainName = 'dexter.lab'
        },
        @{ 
            # Individual node information hashtable
            NodeName = '192.168.1.10' # Ipv6 loopback address
            Credential = $(New-Object -TypeName PSCredential -ArgumentList 'PSRemotely', $(ConvertTo-SecureString -String 'T3stPassw0rd#' -AsPlainText -Force))
            ServiceName = 'Bits'
        }
    )
}

# PSRemotely tests
PSRemotely -ConfigurationData $ConfigData  {

    Node $AllNodes.NodeName {

        Describe 'Service test' {
			
			$Service = Get-Service -Name $Node.ServiceName
			
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

## Example - using credential hash along with the IPv4 address as the node name
Below is an example showing how to create a hashtable containing the nodenames as the key and credential object as the value, this hashtable can be
passed as an argument to the PSRemotely framework.

```powershell
$CredHashTable = @{
    '192.168.1.10'= $(Import-CliXML -Path .\Compute_Cred.xml); # Importing the cred
    '192.168.1.11'= $(New-Object -TypeName PSCredential -ArgumentList 'Administrator',
                    (ConvertTo-SecureString -String 'T3stPassw0rd#' -AsPlainText -Force)) # Creating the credential Object
}

# Remotely tests
PSRemotely -credentialHash $CredHashTable {
	Node "192.168.1.10","192.168.1.11" {
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