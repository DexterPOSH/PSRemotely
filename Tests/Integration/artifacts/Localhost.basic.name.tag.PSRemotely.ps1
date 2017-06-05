<#
.Synopsis
   Example demonstrating use of PSRemotely to run simple validation tests on a Node (localhost here).
.DESCRIPTION
   This is a straight forward example showing how to use PSRemotely DSL.
#>

PSRemotely {
	Node localhost {
		# Describe with named parameters
		Describe -Name 'Test1' -Tag tag1 {
			It "Should pass" {
				$True | Should Be $True
			}
		}

		# Describe with named parameters
		Describe -Tag tag2 -Name 'Test2'  {
			It "Should pass" {
				$True | Should Be $True
			}
		}
		
		# Describe with name as positional parameter
		Describe 'Test3' -Tag tag3 {
			It "Should pass" {
				$True | Should Be $True
			}
		}

		# Describe with name as positional parameter
		Describe -Tag tag4 'Test4'  {
			It "Should pass" {
				$True | Should Be $True
			}
		}
		
		# Describe plain usage
		Describe 'Test5'  {
			It "Should pass" {
				$True | Should Be $True
			}
		}
		
		# Describe plain usage
		Describe -Name 'Test5'  {
			It "Should pass" {
				$True | Should Be $True
			}
		}

		
		# Describe with named parameters
		Describe  -Name 'Test6'  {
			It "Should pass" {
				$True | Should Be $True
			}
		} -Tag tag6
		
		# Describe with named parameters
		Describe  'Test7'  {
			It "Should pass" {
				$True | Should Be $True
			}
		} -Tag tag7
	}
}
