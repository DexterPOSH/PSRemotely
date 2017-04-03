if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}

$PSVersion = $PSVersionTable.PSVersion.Major
# PSRemotely Test file to be used for this Integration test.
$RemotelyTestFile = "$env:BHProjectPath\Tests\Integration\artifacts\Localhost.basic.PSRemotely.ps1"
# use a dummy artifact with PSRemotely-
$RemotelyJSONFile = "$Env:BHPSModulePath\PSRemotely.json"
$ArtifactsPath = "$Env:BHPSModulePath\lib\Artifacts"
$RemotelyConfig = ConvertFrom-Json -InputObject (Get-Content $RemotelyJSONFile -Raw)

Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Set-PSRemotelyToUseDummyArtifact -Path $RemotelyJSONFile
Copy-DummyArtifact -Path "$ArtifactsPath\DeploymentManifest.xml"

# import the module to load the above changes
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

# Import the TestHelpers
Get-ChildItem -Path "$env:BHProjectPath\Tests\TestHelpers\*.psm1" |
	Foreach-Object {
		Remove-Module -Name $PSitem.BaseName -Force  -ErrorAction SilentlyContinue # reload the module, the script module might have changes
		Import-Module -Name $PSItem.FullName -Force
	}

try {
	Describe "PSRemotely Basic usage, with PS V$($PSVersion)" -Tag Integration {
		# Arrange
		

		# Act, Invoke PSRemotely
		$Result = Invoke-PSRemotely -Script $RemotelyTestFile
		
		# Assert

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
					$Object.Tests[0].TestResult.Describe | Should Be 'Bits Service Test'
					$Object.Tests[0].TestResult.Name | Should BeExactly 'Should be running'
					$Object.Tests[0].TestResult.Result | Should Be 'Failed'
					$Object.Tests[0].TestResult.ErrorRecord | Should NOT BeNullOrEmpty
				}
					
			}
		} 

	}

	Describe 'Re run a test using JSON input' -Tag Integration {

        # Arrange
        Mock -CommandName New-PSSession -MockWith {}

        # Act 
        # PSRemotely have already been invoked in above Describe block, it should persist the PSRemoting Session
        $InputObject = [PSCustomObject]@{
            "NodeName" = 'localhost';
            "Tests" = @(
                @{
                    "Name" = "Bits Service test"
                }
            )
        }

        $Result = Invoke-PSRemotely -JSONInput ($InputObject | ConvertTo-Json)
        
        Context "Assert that the Node was already bootstrapped" {

            It "Should not try to open a PSSession to the remote node" {
                # For re running the tests, already existing PSSession are 
                Assert-MockCalled -CommandName New-PSSession -Times 0 -Exactly
            }
        }
        #Assert 
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
					$Object.Tests[0].TestResult.Describe | Should Be 'Bits Service Test'
					$Object.Tests[0].TestResult.Name | Should BeExactly 'Should be running'
					$Object.Tests[0].TestResult.Result | Should Be 'Failed'
					$Object.Tests[0].TestResult.ErrorRecord | Should NOT BeNullOrEmpty
				}
					
			}
		} 

	}

}
finally {
	Clear-PSRemotelyNodePath
    Clear-RemoteSession
	Reset-PSRemotelyToUseDummyArtifact -Path $RemotelyJSONFile
	Remove-DummyArtifact -Path "$ArtifactsPath\DeploymentManifest.xml"
	Get-PSSession | Remove-PSSession
}
