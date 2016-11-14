Synopsis
============
PS Remotely, started as a fork of the [Remotely project](https://github.com/PowerShell/Remotely) and over the time grew out of it.
In a nutshell it let's you execute Pester tests against a remote machine. Remotely can use PoshSpec style infrastucture validation tests too.

It supports copying of the modules and artefacts to the remote node before the Pester tests are run. 

Description
======================
PS Remotely exposes a DSL which makes it very easy to run tests on the remote nodes.
If you already have pester tests then you need to just wrap them inside the Remotely keyword and specify the node information using the Node keyword.

PS Remotely workflow is as under :

1. Read Remotely.json file to determine the path & modules to be used on the remote nodes.
2. Bootstrap the remote nodes, this involves 
    - Testing the remote node path exists.
    - All the modules required are copied from the Lib/ folder to the remote node.
3. Drop the Pester tests (Describe blocks) as individual tests file on the remote node. Also copy the items defined in the Remotely.json, which are placed under Artefacts/ folder inside local Remotely folder.
4. Invoke the tests using background jobs and output a JSON object back.

Example - Basic
============
Already existing Pester test:

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
If you want to run the very same tests on the remote node named say AD, then below is how you use PS Remotely.

Usage with PS Remotely:

```powershell
Remotely {
	Node AD {
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

Output of the above is a JSON object :

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

Example - Use Configuration Data 
============

PS Remotely allows you to use DSC style configuration data for specifying the node configuration.
Also you can reference the $Node variable inside your tests, PS Remotely creates the node variable in the PSSession after reading the configuration data.


```powershell
$ConfigurationData = @{
	AllNodes = @(
		@{
			NodeName='*';
			DomainFQDN='dexter.lab';
		},
		@{
			NodeName='VM1';
			ServiceName = 'bits';
			Type='Compute';

		},
		@{
			NodeName='VM2';
			ServiceName = 'winrm';
			Type='Storage';
		}
	)
}

Remotely -Verbose -ConfigurationData $ConfigurationData {
	
    Node $AllNodes.Where({$PSItem.Type -eq 'Compute'}).NodeName {
		
        # service test
        Describe 'Service test' {
		
	        $Service = Get-Service -Name $node.ServiceName
			
	        It "Should have a service named bits" {
		        $Service | Should Not BeNullOrEmpty
	        }
			
	        it 'Should be running' {
		        $Service.Status | Should be 'Running'
	        }
        }

    }
```

Example - Use Configuration Data and specify credentials
============


Links
============
* https://github.com/PowerShell/Remotely
* https://github.com/pester/Pester

Running Tests
=============
Pester-based tests are located in ```<branch>/Remotely.Tests.ps1```

* Ensure Pester is installed on the machine
* Run tests:
    .\Remotely.Tests.ps1
