$LocalAdminCreds = New-Object -Typename PSCredential -ArgumentList 'Administrator',$(ConvertTo-SecureString -String 'Dell1234' -AsPlainText  -Force)
$CredHash = @{
    'WDS' = $LocalAdminCreds
    'PXE' = $LocalAdminCreds
}

Describe "Add-Numbers" {
    It "adds positive numbers on two remote systems" {
        Remotely ($CredHash.Keys) { 2 + 3 } | Should Be 5
    }

    It "gets verbose message" {
        $sum = Remotely 'WDS','PXE' { Write-Verbose -Verbose "Test Message" }
        $sum.GetVerbose() | Should Be "Test Message"
    }

    It "can pass parameters to remote block with different credentials" {
        $num = 10
        $process = Remotely 'VM1' { param($number) $number + 1 } -ArgumentList $num -CredentialHash $CredHash
        $process | Should Be 11
    }
}

Remotely {
	Node localhost {
		Describe 'Bits Service test' {
			
			$BitsService = Get-Service -Name Bits
			
			It "Should have a service named bits" {
				$BitsService | Should Not BeNullOrEmpty
			}
			
			it 'Should be running' {
				$BitsService.Status | Should be 'Running'
			}
		}		
	}
}

$ConfigurationData = @{
	AllNodes = @(
		{
			NodeName='*';
			FQDN='Lajolla.lab';
			DNSServer=@('192.168.10.1','192.168.10.2')

		},
		{
			NodeName='DellBlr2C2A';
			MgmtIPAddress = '192.168.10.11';
			Storage1IPAddress = '192.168.40.11';
			Storage2IPAddress = '192.168.50.11';
			Type='Compute';

		},
		{
			NodeName='DellBlr2S1';
			Storage1IPAddress = '192.168.40.21';
			Storage2IPAddress = '192.168.50.21';
			Type='Storage';
		}
	)
}

Remotely 'ComputeNodeTest' -ConfigurationData $ConfigurationData {
	Node $AllNodes.NodeName.Where({$PSitem.Type -eq 'Compute'}) {
		#region DNS test
		Describe "TestDNSConnectivity" -Tags DNS {
	
			Context 'DNS Reachable over Mgmt network' {

				$Node.DNSServer.Foreach({
						TCPPortWithSourceAddress $PSItem 53 -SourceIP $node.MgmtIPAddress { Should Be $true }
					})
			}

			Context 'DNS resolves the FQDN' {
				$Node.DNSServer.Foreach({
						# DNSHost <Name to Resolve> <DNSServer to user> <Assertion> <type of Name query>
						DNSHost $node.FQDN $PSitem { Should NOT Be $null }
					})
			}
				
		} #end Describe TestDNSConnectivity
		
		#endregion
		
		
		#region AD test
		Describe 'TestADConnectivity' -Tags AD {
			
			Context 'AD reachable over Mgmt network' {
				TCPPortWithSourceAddress $Node.FQDN 389 -SourceIP $node.MgmtIPAddress { Should Be $true }	
			}	
		}
		#endregion
		
		#region IP connectivity test
		Describe 'TestIPConnectivity' -Tags IP {
			
		}
		#endregion
	}
}


Remotely 'StorageNodeTest' -ConfigurationData $ConfigurationData {
	Node $AllNodes.NodeName.Where({$PSitem.Type -eq 'Storage'}) {
		#region DNS test
		Describe "TestDNSConnectivity" -Tags DNS {
	
			Context 'DNS Reachable over Storage1 network' {

				$Node.DNSServer.Foreach({
						TCPPortWithSourceAddress $PSItem 53 -SourceIP $node.Storage1IPAddress { Should Be $true }
					})
			}
			
			Context 'DNS Reachable over Storage2 network' {

				$Node.DNSServer.Foreach({
						TCPPortWithSourceAddress $PSItem 53 -SourceIP $node.Storage2IPAddress { Should Be $true }
					})
			}

			Context 'DNS resolves the FQDN' {
				$Node.DNSServer.Foreach({
						# DNSHost <Name to Resolve> <DNSServer to user> <Assertion> <type of Name query>
						DNSHost $node.FQDN $PSitem { Should NOT Be $null }
					})
			}
				
		} #end Describe TestDNSConnectivity
		
		#region AD test
		Describe 'TestADConnectivity' -Tags AD {
			
			Context 'AD reachable over Storage1 network' {
				TCPPortWithSourceAddress $Node.FQDN 389  $node.Storage1IPAddress { Should Be $true }	
			}
			
			Context 'AD reachable over Storage2 network' {
				TCPPortWithSourceAddress $Node.FQDN 389  $node.Storage2IPAddress { Should Be $true }	
			}	
		}
		#endregion
		
	}
