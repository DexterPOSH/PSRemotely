Describe 'Node' {

	Context 'Node is localhost' {
		# Happy path test
		# Arrange

		# Act 
		Node localhost { 
			Describe Service {
				Service w32time Status { Should Be Running }
			}
		} -ErrorVariable nodeError -WarningVariable nodeWarning
			
		# Assert 		
		It 'Should open' {
					
		}

		It 'Shoould bootstrap the nodes' {

		}

		It 'Should add the AllNodes variable to the remotely node session' {

		}

		it 'Should'
	}
}