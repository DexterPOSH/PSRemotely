<#
.Synopsis
   Example demonstrating use of PSRemotely to run simple validation tests on a Node (localhost here).
.DESCRIPTION
   This is a straight forward example showing how to use PSRemotely DSL.
   To Use:
     1. Copy to \Tests\Integration\ folder and rename <Name>.PSRemotely.tests.ps1 (e.g. localhost.basic.PSRemoltey.tests.ps1)
     2. Customize TODO sections.
     3. Create test PSRemotely test file <Name>.config.ps1 (e.g. localhost.basic.Tests.ps1).
#>
param([hashtable]$Arguments)

# Configuration Data, can be passed as an argument or from a .psd1 or .json file
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

PSRemotely -ArgumentList $arguments -ConfigData $ConfigData {

    Node $AllNodes.Where({$PSItem.Type -eq 'Storage'}).NodeName {
        Describe "Node Service test" {
			
			$Service = Get-Service -Name $node.ServiceName # using node specific attributes
			
			It "Should have a service named $ServiceName" { # using $ServiceName variable
				$Service | Should Not BeNullOrEmpty
			}
			
			It 'Should be running' {
				$Service.Status | Should be 'Running'
			}
		}
    }

}