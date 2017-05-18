<#
.Synopsis
   Example demonstrating use of PSRemotely with Configuration data
.DESCRIPTION
   This is a straight forward example showing how to use PSRemotely DSL.
#>

# Configuration Data
$ConfigData = @{
	AllNodes = @(
		@{
			NodeName='*';
			DomainFQDN='dexter.lab';
		},
		@{
			NodeName="$env:ComputerName";
			ServiceName = 'bits';
			Type='Compute';

		},
		@{
			NodeName='localhost';
			ServiceName = 'winrm';
			Type='Storage';
		}
	)
}

# PSRemotely tests
PSRemotely -ConfigurationData $ConfigData {
	Node $AllNodes.Where({$PSItem.Type -eq 'Compute'}).NodeName {
		Describe 'Service test' {
			
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
