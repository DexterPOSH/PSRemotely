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
            NodeName = 'localhost'
            IPAddress = '127.0.0.1'
            Credential = $(New-Object -TypeName PSCredential -ArgumentList 'PSRemotely', $(ConvertTo-SecureString -String 'T3stPassw0rd#' -AsPlainText -Force))
            TestAttribute = 'TestValue'
        }
    )
}


PSRemotely -ConfigurationData $ConfigData -PreferNodeProperty  IPAddress {

    Node $AllNodes.NodeName {

        Describe 'Testing Node variable' {

            It 'SHould have TestAttribute set' {
                $Node.TestAttribute | Should Be 'TestValue'
            }

            It 'Should NOT have the Credential set, Credential used to connect does not get passed to the Remote session' {
                $Node.Credential | Should BeNullOrEmpty
            }

            It 'Should have common node property e.g. DomainName set' {
                $Node.DomainName | Should Be 'dexter.lab'
            }
        }
    }
}