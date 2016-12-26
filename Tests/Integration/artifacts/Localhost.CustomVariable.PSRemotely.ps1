<#
.Synopsis
   Example demonstrating use of PSRemotely to specify argument list.
.DESCRIPTION
   This is a straight forward example showing how to use PSRemotely DSL.
   #>
param([hashtable]$Arguments)

PSRemotely -ArgumentList $arguments {

    Node localhost {
        Describe "Node Service test" {
			
			$Service = Get-Service -Name $ServiceName
			
			It "Should have a service named $ServiceName" {
				$Service | Should Not BeNullOrEmpty
			}
			
			It 'Should be running' {
				$Service.Status | Should be 'Running'
			}
		}
    }

}