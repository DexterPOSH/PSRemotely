
InModuleScope -ModuleName Remotely {
    
    Describe 'Get-TestName' -Tag UnitTest {
        
        Context 'TestName is a single quoted string' {
            $Content = {
                Describe 'SingleQuoteTestName' -tag UnitTest {
    
                It 'Should do Something' {
                    $true | should be $true
                }   
            }

        }    
    }
    
}
