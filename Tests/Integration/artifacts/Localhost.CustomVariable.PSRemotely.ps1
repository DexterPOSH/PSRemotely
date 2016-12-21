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

PSRemotely -ArgumentList $arguments {

    Node localhost {
        Describe "Node Service test" {
			
			$BitsService = Get-Service -Name $ServiceName
			
			It "Should have a service named $ServiceName" {
				$BitsService | Should Not BeNullOrEmpty
			}
			
			It 'Should be running' {
				$BitsService.Status | Should be 'Running'
			}
		}
    }

}