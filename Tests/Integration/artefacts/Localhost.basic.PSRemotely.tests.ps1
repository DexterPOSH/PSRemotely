<#
.Synopsis
   Example demonstrating use of PS Remotely to run simple validation tests on a Node (localhost here).
.DESCRIPTION
   This is a straight forward example showing how to use PS Remotely DSL.
   To Use:
     1. Copy to \Tests\Integration\ folder and rename <Name>.PSRemotely.tests.ps1 (e.g. localhost.basic.PSRemoltey.tests.ps1)
     2. Customize TODO sections.
     3. Create test PS Remotely test file <Name>.config.ps1 (e.g. localhost.basic.Tests.ps1).
#>

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
