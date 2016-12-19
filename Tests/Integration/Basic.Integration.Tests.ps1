if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

# Import the TestHelpers
Get-ChildItem -Path "$env:BHProjectPath\Tests\TestHelpers\*.psm1" |
	Foreach-Object {
		Import-Module -Name $PSItem -verbose -Force
	}


$PSVersion = $PSVersionTable.PSVersion.Major
# PSRemotely Test file to be used for this Integration test.
$RemotelyTestFile = "$env:BHProjectPath\Tests\Integration\artifacts\Localhost.basic.PSRemotely.ps1"
$RemotelyJSONFile = "$Env:BHPSModulePath\PSRemotely.json"

try {
	Describe "PSRemotely Basic usage, with PS V$($PSVersion)" -Tag Integration {
	
		# Act, Invoke PSRemotely
		$Result = Invoke-PSRemotely -Script $RemotelyTestFile
		$RemotelyConfig = ConvertFrom-Json -InputObject (Get-Content $RemotelyJSONFile -Raw)
		# Assert

		# First verify that all the Node related details are stored in the PSRemotely global var
		Context 'Global Variable PSRemotely validation' {
			
			It "Should check if the global variable PSRemotely exists" {
				$Global:PSRemotely | Should NOT BeNullOrEmpty
			}

			It 'Should check if the PSRemotelyNodePath was picked from the PSRemotely.JSON' {
				$Global:PSRemotely.PSRemotelyNodePath | Should Be $RemotelyConfig.PSRemotelyNodePath
			}

			It 'Should check if the ModulesRequired was picked from the PSRemotely.JSON' {
				foreach ($module in $Global:PSRemotely.ModulesRequired) {
					$moduleInConfig = $RemotelyConfig.ModulesRequired.Where({$module['ModuleName']})
					$module['ModuleName'] | Should BeExactly $moduleInConfig.ModuleName
					$module['ModuleVersion'] | Should BeExactly $moduleInConfig.ModuleVersion
				}
			}

			It 'Should have a NodeMap for the Node created' {
				$Global:PSRemotely.NodeMap[0].NodeName | Should Be 'localhost'
			}

			It 'Should have the PathStatus true for the NodeMap (implies the PSRemotelyNodePath exists)' {
				$Global:PSRemotely.NodeMap[0].PathStatus | Should Be $True
			}

			It 'Should have the ModuleStatus true for the Node (implies all modules were copied to the PSRemotely Node)' {
				$Global:PSRemotely.NodeMap[0].ModuleStatus.Keys.ForEach({
					$Global:PSRemotely.NodeMap[0].ModuleStatus["$PSitem"] | Should Be $true
				})
			}

			It 'Should maintain a PSSession Hashtable to the node' {
				$Global:PSRemotely.SessionHashTable | Should NOT BeNullOrEmpty
				$Global:PSRemotely.SessionHashTable.ContainsKey('Localhost') | Should Be $True
			}
			
		}

		# Test if the PSSession was opened to the node
		Context 'Validate that PSSession was created for the PSRemotely node' {
			$Session = Get-PSSession -Name PSRemotely-Localhost -ErrorAction SilentlyContinue

			It 'Should have opened a PSSession to the Node' {
				$Session | Should NOT BeNullOrEmpty	
			}

			It 'Should be in Opened state (live sessions maintained)' {
				$Session.State | Should Be 'Opened'
			}
		}

		# Test if the required modules & artifacts were copied to the PSRemotely node
		Context '[BootStrap] Validate the PSRemotelyNodePath has modules & artifacts copied' {
			# In this context validate that the required modules and artifacts were copied to the Node

			It 'Should create PSRemotelyNodePath on the Node' {
				$Global:PSRemotely.PSRemotelyNodePath | Should Exist
			}

			It 'Should copy the required modules in PSRemotelyNodePath' {
				$Global:PSRemotely.ModulesRequired.ForEach({
					"$($Global:PSRemotely.PSRemotelyNodePath)\lib\$($PSItem.ModuleName)\$($PSItem.ModuleVersion)\$($PSitem.ModuleName).psd1" |
						Should Exist
				})
			}

			It 'Should copy the required artifacts in PSRemotelyNodePath' {
				"$($Global:PSRemotely.PSRemotelyNodePath)\lib\artifacts" | Should Exist
				$Global:PSRemotely.artifactsRequired.ForEach({
					"$($Global:PSRemotely.PSRemotelyNodePath)\lib\artifacts\$($PSItem)" | Should Exist
				})
			}
		}

		# Test if the Node specific tests were copied to the PSRemotely node
		Context '[BootStrap] Test if the Node tests were copied' {

			It 'Should drop a file with format <NodeName>.<Describe_block>.Tests.ps1' {
				"$($Global:PSRemotely.PSRemotelyNodePath)\$($env:ComputerName).Bits_Service_test.Tests.ps1" | 
					Should Exist
			}

			It 'Should create a Pester NUnit report for the Node' {
				"$($Global:PSRemotely.PSRemotelyNodePath)\$($env:ComputerName).xml" |
					Should Exist
			}	
		}

		Context 'Validate the JSON Ouput' {
			$Service = Get-Service -Name Bits
			$Object = $Result | ConvertFrom-JSON
			if ($Service.Status -eq 'Running') {
				It 'Should have the Node test status set as True' {
					$Object.Status | Should Be $True
				}
				
				It 'Should return the result of each Describe block' {
					$Object.Tests[0].Result | Should Be $True
					$Object.Tests[0].Name | Should be 'Bits Service test'
				}

				It 'Should have the TestResult empty' {
					$Object.Tests[0].TestResult | Should BeNullOrEmpty
				}
			}
			else {

				It 'Should have the Node test status set as False' {
					$Object.Status | Should Be $False
				}

				It 'Sould return the result of each Describe block' {
					$object.Tests[0].Result | Should Be $False
					$Object.Tests[0].Name | Should be 'Bits Service test'
				}

				It 'Should Write Error thrown to TestResult' {
					$Object.Tests[0].TestResult | Should NOT BeNullOrEmpty
				}

				It 'Should return more details about the test failed in the TestResult' {
					$Object.Tests[0].TestResult.Describe | Should BeExactly 'Bits Service Test'
					$Object.Tests[0].TestResult.Name | Should BeExactly 'Should be running'
					$Object.Tests[0].TestResult.Result | Should Be 'Failed'
					$Object.Tests[0].TestResult.ErrorRecord | Should NOT BeNullOrEmpty
				}
					
			}
		} 

	}

	Describe 'PSSession opened during PSRemotely run, persist.' -Tag Integration {
		
		Context 'Using the Get-RemoteSession function' {
			$RemoteSession = Get-RemoteSession

			It 'Should return the PSSession starting with name Remote-NodeName' {
				$RemoteSession.Name | Should Be 'PSRemotely-Localhost'
			}

			It 'Should return the PSSession in opened state' {
				$RemoteSession.State | Should BeExactly 'Opened'
			}
			
		}

		Context 'Using the global variable PSRemotely' {

			It 'Should have the PSSession maintained in the Session hashtable' {
				$Global:PSRemotely.SessionHashTable | Should NOT BeNullOrEmpty
				$Global:PSRemotely.SessionHashTable.ContainsKey('Localhost') | Should Be $True
			}
		}
	}

	Describe 'Clearing the persisted PSSession after a PSRemotely run' -Tag Integraion {

		Context 'Clear all open PSSessions after PSRemotely run' {
			Clear-RemoteSession

			It 'Should clear all PSRemotely PSSessions' {
				Get-RemoteSession | Should BeNullOrEmpty
				Get-PSSession -Name PSRemotely-* | Should BeNullOrEmpty
			}
		}

		Context 'Should update the global variable PSRemotely' {

			It 'Should clear out Session Hashtable' {
				$Global:PSRemotely.SessionHashTable | Should  BeNullOrEmpty
			}
		}
	}
}
finally {
	Clear-PSRemotelyNodePath
    #Clear-RemoteSession
}
