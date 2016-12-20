<#
.Synopsis
   Example demonstrating use of PSRemotely with Configuration data supplied from a JSON file
.DESCRIPTION
   This is a straight forward example showing how to use PSRemotely DSL.
   To Use:
     1. Copy to \Tests\Integration\ folder and rename <Name>.PSRemotely.tests.ps1 (e.g. localhost.basic.PSRemoltey.tests.ps1)
     2. Customize TODO sections.
     3. Create test PSRemotely test file <Name>.config.ps1 (e.g. localhost.basic.Tests.ps1).
#>

# Configuration Data path
$ConfigDataPath = "$PSScriptRoot\ConfigData.psd1"

$ConfigTemplate = "$PSScriptRoot\ConfigData.Template.psd1"
$PSD1Content = Expand-ComputerName -Path $ConfigTemplate
Set-Content -Value $PSD1Content -Path $ConfigDataPath -Force 

# PSRemotely tests
PSRemotely -Path $ConfigDataPath  {
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