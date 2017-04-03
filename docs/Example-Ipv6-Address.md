# PSRemotely example using IPv6 address for targeting remote nodes.

PSRemotely allows usage of IPv6 addresses for targeting operations validation to them.
The only gotcha is that, the machine where the PSRemotely will run should be configured to connect using IPv6 address to the remote node.
This typically requires configuring the TrustedHosts for the local winrm client.

Note that if you are using IPv6 address then you have to explicitly specify the credentials to be used to connect to the remote node.
PSRemotely allows two different approaches for specifying the credential.

- [Using Credential hash](http://psremotely.readthedocs.io/en/latest/Example-CredentialHash/)
- [Specifying Credential in the Configuration data](http://psremotely.readthedocs.io/en/latest/Example-ConfigurationData-Credential/)


## Example - specifying credential in the configuration data along with the IPv6 address used as the node name
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
            NodeName = 'fe80::4448:1de4:5e32:4f46%30' # Ipv6 Address used as the node name here
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

## Example - using credential hash along with IPv6 address used as the node names.
Below is an example showing how to create a hashtable containing the nodenames as the key and credential object as the value, this hashtable can be
passed as an argument to the PSRemotely framework.

```powershell
$CredHashTable = @{
    'fe80::6cdc:6969:7a7a:20ce'= $(New-Object -TypeName PSCredential -ArgumentList 'Domain\Administrator',
                    (ConvertTo-SecureString -String 'TestPassword#12' -AsPlainText -Force))
    'fe80::4448:1de4:5e32:4f46'= $(New-Object -TypeName PSCredential -ArgumentList 'Domain\Administrator',
                    (ConvertTo-SecureString -String 'TestPassword#12' -AsPlainText -Force)) # Creating the credential Object
}

# Remotely tests
PSRemotely -credentialHash $CredHashTable -Verbose {
	Node "fe80::6cdc:6969:7a7a:20ce",'fe80::4448:1de4:5e32:4f46' {
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