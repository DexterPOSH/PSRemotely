# COnfiguration data, at the moment lives here but this can be generated on deman and separated from tests later
$configdata = @{
    AllNodes = @(
        @{
            # common node information hashtable
            NodeName = '*';
        },
        @{ 
            # Individual node information hashtable
            NodeName = 'localhost'
            IPAddress = '127.0.0.1'
            Credential = $(New-Object -TypeName PSCredential -ArgumentList 'PSRemotely', $(ConvertTo-SecureString -String 'T3stPassw0rd#' -AsPlainText -Force))
            NetworkConfig = @(
                @{
                    Name = 'vEthernet (management)';
                    IPv4Address = '172.18.50.1';
                },
                @{
                    Name = 'vEthernet (storage1)';
                    IPv4Address = '172.18.70.1';
                },
                @{
                    Name = 'vEthernet (storage2)';
                    IPv4Address = '172.18.100.1';
                }
                
            )
        }
    )
}


PSRemotely -ConfigurationData $ConfigData -PreferNodeProperty  IPAddress -Verbose {

    Node $AllNodes.NodeName {

        Describe 'testing domain' {

            It 'SHould be part of the domain' {
                $CompSystem = Get-CimInstance -ClassName Win32_Computersystem
                $CompSystem.PartofDomain | SHould be $True
            }
        }
    }
}