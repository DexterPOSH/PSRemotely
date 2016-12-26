<#
.Synopsis
   Example demonstrating use of PSRemotely to run simple validation tests on a Node (localhost here).
.DESCRIPTION
   This is a straight forward example showing how to use PSRemotely DSL.
#>

PSRemotely {
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
