<#
.Synopsis
   Example demonstrating use of PSRemotely with Configuration data supplied from a JSON file
.DESCRIPTION
   This is a straight forward example showing how to use PSRemotely DSL.
#>
# Configuration Data path
$ConfigDataPath = "$PSScriptRoot\ConfigData.json"

$ConfigTemplate = "$PSScriptRoot\ConfigData.Template.json"
$JSONContent = Expand-ComputerName -Path $ConfigTemplate
#$JSONContent | Out-File -Path "$PSScriptRoot\ConfigData.json" -Force'
Set-Content -Value $JSONContent -Path $ConfigDataPath -Force 

# PSRemotely tests
PSRemotely -Path $ConfigDataPath {
	Node $AllNodes.Where({$PSItem.Type -eq 'Compute'}).NodeName {
		Describe 'Service test' {
			
			$Service = Get-Service -Name $node.ServiceName # See the use of $node variable here
			
			It "Should have a service named $($node.ServiceName)" {
				$Service | Should Not BeNullOrEmpty
			}
			
			it 'Should be running' {
				$Service.Status | Should be 'Running'
			}
		}		
	}
}
