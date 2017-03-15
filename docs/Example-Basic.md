# Basic PSRemotely Example

If you already have Pester tests for operation validation in place, then PSRemotely adds another abstraction on top, by allowing to run all these tests remotely.
Bottom line is, PSRemotely enables Remote Operations Validation.


For Example - You have the below test to validation that the Bits service is running on a Server

```powershell
Describe 'Bits Service test' {
    
    $BitsService = Get-Service -Name Bits
    
    It "Should have a service named bits" {
        $BitsService | Should Not BeNullOrEmpty
    }
    
    it 'Should be running' {
        $BitsService.Status | Should be 'Running'
    }
}
```

Now if you want to run the very same tests across multiple remote nodes named say Server1, Server2, Server3 etc then below is how you use PS Remotely DSL.

Usage with PS Remotely:

```powershell
Remotely {
	Node Server1, Server2, Server3 {
		
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

```
So you take the investments in your tests and let PS Remotely do the underlying work of copying the required tests, invoking them and giving you simplified results back.
Once you have the tests file reeady, below is how you invoke the PS Remotely framework : 

```powershell
Invoke-Remotely -Script <Path_to_PSRemotely.ps1>
```

Output of the above is a JSON object for the Node on which the tests were run. The property Status is true if all the tests (Describe blocks) passed on the remote node.
Tests property is an array of individual tests (Describe block) run on the Remotely node, If all the tests pass then an empty JSON object array of *TestResult* is returned 
otherwise the Error record thrown by Pester is returned :

```json
{
    "Status":  true,
    "NodeName":  "AD",
    "Tests":  [
                  {
                      "TestResult":  [

                                     ],
                      "Result":  true,
                      "Name":  "Service test"
                  }
              ]
}
```
