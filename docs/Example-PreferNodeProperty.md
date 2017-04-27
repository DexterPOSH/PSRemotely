# PSRemotely example using PreferNodeProperty to use IPV4/IPv6 address as part of the Node configuration data

Though PSRemotely supports using IPv4/IPv6 address as the nodenames for targeting remote nodes for operations validaiton.
There is a downside to it, the output JSON object will contain the nodename as the cryptic IPv4/IPv6 address.
So in order to keep a friendly name for the node names and yet be able to specify the IPv4/IPv6 address to be used to connect to the remote node
the PreferNodeProperty parameter comes into picture. Thanks to [Iain Brighton](https://github.com/iainbrighton) for the idea.

See below the configuration data for the node named 'TestVM', which is just a friendly name for identifying the node.
Now in the configuration data an attribute named **IPAddress** is specified and I want to instruct PSRemotely to use this to connect to the node.
The above is achieved by specifying the argument **IPAddress** to the parameter *-PreferNodeProperty* with the PSRemotely keyword.

Note - Below the Credential attribute (hard constraint on the name) has to be explicilty specified when IPv4/IPv6 address are used. Also the credential attribute is removed and not available on the remote session. So you can't reference credential e.g. *$Node.Credential* in your ops validation tests.

As an alternative you can take a look at specifying credentials using CredentialHash with PSRemotely.

```powershell
# COnfiguration data, at the moment lives here but this can be generated on deman and separated from tests later
$configdata = @{
    AllNodes = @(
        @{
            # common node information hashtable
            NodeName = '*';
            DomainName = 'dexter.lab'
        },
        @{ 
            # Individual node information hashtable
            NodeName = 'TestVM' # Firendly name to identify this node
            IPAddress = '192.168.1.1' # The IPv4 address to be used to connect over PSRemoting
            Credential = $(New-Object -TypeName PSCredential -ArgumentList 'PSRemotely', $(ConvertTo-SecureString -String 'T3stPassw0rd#' -AsPlainText -Force)) # Since we are using IPV4 address, credential has to be explicitly specified
            TestAttribute = 'TestValue'
        }
    )
}


PSRemotely -ConfigurationData $ConfigData -PreferNodeProperty  IPAddress -Verbose {

    Node $AllNodes.NodeName {

        Describe 'Testing Node variable' {

            It 'SHould have TestAttribute set' {
                $Node.TestAttribute | Should Be 'TestValue'
            }

            It 'Should NOT have the Credential set, Credential used to connect does not get passed to the Remote session' {
                $Node.Credential | Should BeNullOrEmpty # See here that the Credential attribute is not populated in the remote PSSession
            }

            It 'Should have common node property e.g. DomainName set' {
                $Node.DomainName | Should Be 'dexter.lab'
            }
        }
    }
}
```

Below is the output when the above PSRemotely tests are run:

```json
{
    "Status":  true,
    "NodeName":  "TestVM",
    "Tests":  [
                  {
                      "TestResult":  [

                                     ],
                      "Result":  true,
                      "Name":  "Testing Node variable"
                  }
              ]
}
```
Note - Though the IPaddress was used to connect to the Remote node, the output JSON object has the friendly nodename.