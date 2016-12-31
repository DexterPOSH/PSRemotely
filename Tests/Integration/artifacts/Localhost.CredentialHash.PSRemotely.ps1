<#
.Synopsis
   Example demonstrating use of PSRemotely with Credential Hash
.DESCRIPTION
   This is a straight forward example showing how to use PS Remotely DSL.
#>
param($CredentialHash)


# Remotely tests
PSRemotely -credentialHash $CredentialHash {
	Node "$env:COMPUTERNAME" {
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
