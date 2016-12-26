<#
.Synopsis
   Example demonstrating use of PSRemotely to specfify Argument list with Configuration data.
.DESCRIPTION	
   This is a straight forward example showing how to use PSRemotely DSL.
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