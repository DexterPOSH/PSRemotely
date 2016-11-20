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
5. It also exports a global variable named $Remotely to which the Node bootstrap map and PSSession information is stored.

Example 1 - Basic
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
Once you have the tests file reeady, below is how you invoke the PS Remotely framework : 

```powershell
Invoke-Remotely -Script <Path_to_Tests.ps1>
```

Output of the above is a JSON object, if the tests pass then an empty JSON object array of *TestResult* is returned 
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

Example 2 - Use Configuration Data 
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
}
```

Another salient feature of PS Remotely is that you can pass a path to a .JSON or .psd1 file housing the configuration data.

```powershell

Remotely -Path C:\Remotely\Prod.ConfigData.json {
	
    Node $AllNodes.Where({$PSItem.Type -eq 'Compute'}).NodeName {
		
        # service test
        Describe 'Service test' {
		
            $Service = Get-Service -Name $node.ServiceName
            
            It "Should have a service named bits" {
                $Service | Should Not BeNullOrEmpty
            }
            
            It 'Should be running' {
                $Service.Status | Should be 'Running'
            }
        }
    }
}
```

Example 3 - Use Configuration Data and specify credentials [This has to be tested]
============

PS Remotely allows you to specify credentials in the Configuration data along with passing a credential hash to the Remotely outside of the Configuration Data.


```powershell
$CredentialHash = @{
    'AD' = $(New-Object -TypeName PSCredential -ArgumentList 'Administrator',(ConvertTo-SecureString -String 'DefaultPass' -AsPlainText -Force));
    'WDS' = $(Import-CliXML -Path C:\Vault\WDS.Cred.xml)
}

Remotely -CredentialHash $CredentialHash {
    Node AD, WDS {

        Describe 'WinRM service tests' {

            $Service = Get-Service -Name $node.ServiceName
            
            It "Should have a service named bits" {
                $Service | Should Not BeNullOrEmpty
            }
            
            It 'Should be running' {
                $Service.Status | Should be 'Running'
            }
        }

    }
}
```

If you are using ConfigurationData then you can specify a note attribute named credential which gets picked up to open a PSSession to the remote node, which PS Remotely uses.
[See RemoteSession.ps1 > Function CreateSessions]

```powershell
$ConfigurationData = @{
	AllNodes = @(
		@{
			NodeName='*';
			DomainFQDN='dexter.lab';
            Credential = $(Get-Credential -UserName 'dexter\delegatedadmin' -Message 'Enter the creds for the delegatedadmin')
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
        Describe 'Service running test' {
		
	        $Service = Get-Service -Name $node.ServiceName

	        It 'Should be running' {
		        $Service.Status | Should be 'Running'
	        }
        }

    }
}
```

Example 4 - Specify a variable to Remotely which needs to be available on the remote nodes.
============

If you needed to make a variable available on the remote node during the invocation of the Pester 
tests then you can specify these as a hashtable to the paramter -ArgumentList.

```powershell
Remotely -ArgumentList @{ServiceName='bits'} {
    Node AD {

        Describe "$ServiceName running test" {
            $Service = Get-Service -Name $ServiceName

	        It 'Should be running' {
		        $Service.Status | Should be 'Running'
	        }

        }
    }
}
```

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
