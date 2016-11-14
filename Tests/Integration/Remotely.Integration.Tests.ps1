$LocalAdminCreds = New-Object -Typename PSCredential -ArgumentList 'Administrator',$(ConvertTo-SecureString -String 'Dell1234' -AsPlainText  -Force)
$CredHash = @{
    'WDS' = $LocalAdminCreds
    'PXE' = $LocalAdminCreds
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
		@{
			NodeName='*';
			DomainFQDN='Lajolla.lab';
			DNSServer=@('192.168.10.1','192.168.10.2')

		},
		@{
			NodeName='DellBlr2C2A';
			ManagementIPv4Address = '192.168.10.11';
			Storage1IPv4Address = '192.168.40.11';
			Storage2IPv4Address = '192.168.50.11';
			ServiceName = 'bits'
			Type='Compute';

		},
		@{
			NodeName='DellBlr2S1';
			Storage1IPv4Address = '192.168.40.21';
			Storage2IPv4Address = '192.168.50.21';
			Type='Storage';
		}
	)
}

Remotely -Verbose -ConfigurationData $ConfigurationData {
	
    Node $AllNodes.Where({$PSItem.Type -eq 'Compute'}).NodeName {
		
        # service test
        Describe 'Service test' {
		
	        $Service = Get-Service -Name $node.ServiceName
			
	        It "Should have a service named bits" {
		        $Service | Should Not BeNullOrEmpty
	        }
			
	        it 'Should be running' {
		        $Service.Status | Should be 'Running'
	        }
        }

    }


    # Storage tests
    Node $AllNodes.Where({$PSitem.Type -eq 'Storage'}).NodeName {
        
        Describe 'TestStorageArray' -tags Storage {

			Context 'Storage arrays should have minimum of 4 SSD' {
				$SSDs = @(Get-StorageEnclosure | Get-PhysicalDisk | Where-Object -FilterScript {$PSitem.MediaType -eq 'SSD'})

				foreach ($ssd in $SSDs) {
					It "$($ssd.FriendlyName) Should be healthy" {
						$ssd.HealthStatus | Should be 'Healthy'
					}
				}

				It "should have minimum of 4 SSD" {
					($SSDs.Count -ge 4 ) | Should be $True
				}
				
			}

			Context 'Storage arrays should have minimum of 8 HDD' {
				$HDDs = @(Get-StorageEnclosure | Get-PhysicalDisk | Where-Object -FilterScript {$PSitem.MediaType -eq 'HDD'})

				foreach ($hdd in $HDDs) {
					It "$($hdd.FriendlyName) Should be healthy" {
						$hdd.HealthStatus | Should be 'Healthy'
					}
				}

				It "should have minimum of 8 HDD" {
					($HDDs.Count -ge 8 ) | Should be $True
				}	
			}
		}
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
