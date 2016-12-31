<#
.Synopsis
   Example demonstrating use of PS PSRemotely with Configuration data and Credential supplied with config data.
.DESCRIPTION
   This is a straight forward example showing how to use PS PSRemotely DSL.
#>
param($Credential)

# Configuration Data
$ConfigData = @{
	AllNodes = @(
		@{
			NodeName='*';
			DomainFQDN='dexter.lab';
            Credential = $Credential
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
		Describe 'Bits Service test' {
			
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
