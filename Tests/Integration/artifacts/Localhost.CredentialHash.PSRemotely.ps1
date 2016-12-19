<#
.Synopsis
   Example demonstrating use of PS Remotely with Credential Hash
.DESCRIPTION
   This is a straight forward example showing how to use PS Remotely DSL.
   To Use:
     1. Copy to \Tests\Integration\ folder and rename <Name>.PSRemotely.tests.ps1 (e.g. localhost.basic.PSRemoltey.tests.ps1)
     2. Customize TODO sections.
     3. Create test PS Remotely test file <Name>.config.ps1 (e.g. localhost.basic.Tests.ps1).
#>
param($CredentialHash)


# Remotely tests
Remotely -credentialHash $CredentialHash {
	Node "$env:ComputerName" {
		Describe 'Bits Service test' {
			
			$Service = Get-Service -Name 'bits'
			
			It "Should have a service named bits" {
				$Service | Should Not BeNullOrEmpty
			}
			
			it 'Should be running' {
				$Service.Status | Should be 'Running'
			}
		}		
	}
}
