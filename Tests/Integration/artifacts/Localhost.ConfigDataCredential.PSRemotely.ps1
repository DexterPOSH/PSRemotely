<#
.Synopsis
   Example demonstrating use of PS Remotely with Configuration data and Credential supplied with config data.
.DESCRIPTION
   This is a straight forward example showing how to use PS Remotely DSL.
   To Use:
     1. Copy to \Tests\Integration\ folder and rename <Name>.PSRemotely.tests.ps1 (e.g. localhost.basic.PSRemoltey.tests.ps1)
     2. Customize TODO sections.
     3. Create test PS Remotely test file <Name>.config.ps1 (e.g. localhost.basic.Tests.ps1).
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

# Remotely tests
Remotely -ConfigurationData $ConfigData {
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
