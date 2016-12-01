if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

# Import the TestHelpers
Get-ChildItem -Path "$env:BHProjectPath\Tests\TestHelpers\*.psm1" |
	Foreach-Object {
		Remove-Module -Name $PSitem.BaseName -Force  -ErrorAction SilentlyContinue
		Import-Module -Name $PSItem.FullName -Force
	}


$PSVersion = $PSVersionTable.PSVersion.Major
# PS Remotely Test file to be used for this Integration test.
$RemotelyTestFiles = @("$env:BHProjectPath\Tests\Integration\artefacts\Localhost.ConfigData.PSRemotely.ps1",
                        "$env:BHProjectPath\Tests\Integration\artefacts\Localhost.ConfigDataFromJSON.PSRemotely.ps1",
                        "$env:BHProjectPath\Tests\Integration\artefacts\Localhost.ConfigDataFromPSD1.PSRemotely.ps1")
$RemotelyJSONFile = "$Env:BHPSModulePath\Remotely.json"

Foreach ($RemotelyTestFile in $RemotelyTestFiles) {
    try {
        Describe "PSRemotely ConfigData usage, with PS V$($PSVersion)" -Tag Integration {
            
            # Act, Invoke Remotely
            $Result = Invoke-Remotely -Script $RemotelyTestFile
            $RemotelyConfig = ConvertFrom-Json -InputObject (Get-Content $RemotelyJSONFile -Raw)
            # Assert

            # First verify that all the Node related details are stored in the Remotely global var
            Context 'Global Variable Remotely validation' {
                
                It "Should check if the global variable Remotely exists" {
                    $Global:Remotely | Should NOT BeNullOrEmpty
                }

                It 'Should check if the RemotelyNodePath was picked from the Remotely.JSON' {
                    $Global:Remotely.RemotelyNodePath | Should Be $RemotelyConfig.RemotelyNodePath
                }

                It 'Should check if the ModulesRequired was picked from the Remotely.JSON' {
                    foreach ($module in $Global:Remotely.ModulesRequired) {
                        $moduleInConfig = $RemotelyConfig.ModulesRequired.Where({$module['ModuleName']})
                        $module['ModuleName'] | Should BeExactly $moduleInConfig.ModuleName
                        $module['ModuleVersion'] | Should BeExactly $moduleInConfig.ModuleVersion
                    }
                }

                It 'Should have a NodeMap for the Nodes created' {
                    $Global:Remotely.NodeMap.count | Should Be 2
                    $Global:Remotely.NodeMap.Where({$_.NodeName -eq 'localhost'}) | Should Be $True
                    $Global:Remotely.NodeMap.Where({$_.NodeName -eq "$env:ComputerName"}) | Should Be $True
                }

                It 'Should have the PathStatus true for the NodeMap (implies the RemotelyNodePath exists)' {
                    $Global:Remotely.NodeMap[0].PathStatus | Should Be $True
                    $Global:Remotely.NodeMap[1].PathStatus | Should Be $True
                }

                It 'Should have the ModuleStatus true for the Node (implies all modules were copied to the Remotely Node)' {
                    $Global:Remotely.NodeMap[0].ModuleStatus.Keys.ForEach({
                        $Global:Remotely.NodeMap[0].ModuleStatus["$PSitem"] | Should Be $true
                    })

                    $Global:Remotely.NodeMap[1].ModuleStatus.Keys.ForEach({
                        $Global:Remotely.NodeMap[1].ModuleStatus["$PSitem"] | Should Be $true
                    })
                }

                It 'Should maintain a PSSession Hashtable to the nodes' {
                    $Global:Remotely.SessionHashTable | Should NOT BeNullOrEmpty
                    $Global:Remotely.SessionHashTable.Count | Should Be 2
                    $Global:Remotely.SessionHashTable.ContainsKey('Localhost') | Should Be $True
                    $Global:Remotely.SessionHashTable.ContainsKey("$env:ComputerName") | Should Be $True
                }
                
            }

            # Test if the PSSession was opened to the node
            Context 'Validate that PSSession was created for the Remotely node' {
                $Sessions = Get-PSSession -Name "Remotely-*" -ErrorAction SilentlyContinue

                It 'Should have opened a PSSession to the Node' {
                    $Sessions | Should NOT BeNullOrEmpty	
                }

                It 'Should be in Opened state (live sessions maintained)' {
                    $Sessions.Count | Should Be 2
                    ($Sessions | Select-Object -Unique -ExpandProperty State) | Should Be 'Opened' 
                }
            }

            # Test if the required modules & artefacts were copied to the Remotely node
            Context '[BootStrap] Validate the RemotelyNodePath has modules & artefacts copied' {
                # In this context validate that the required modules and artefacts were copied to the Node

                It 'Should create RemotelyNodePath on the Node' {
                    $Global:Remotely.RemotelyNodePath | Should Exist
                }

                It 'Should copy the required modules in RemotelyNodePath' {
                    $Global:Remotely.ModulesRequired.ForEach({
                        "$($Global:Remotely.RemotelyNodePath)\lib\$($PSItem.ModuleName)\$($PSItem.ModuleVersion)\$($PSitem.ModuleName).psd1" |
                            Should Exist
                    })
                }

                It 'Should copy the required artefacts in RemotelyNodePath' {
                    "$($Global:Remotely.RemotelyNodePath)\lib\artefacts" | Should Exist
                    $Global:Remotely.ArtefactsRequired.ForEach({
                        "$($Global:Remotely.RemotelyNodePath)\lib\artefacts\$($PSItem)" | Should Exist
                    })
                }
            }

            # Test if the Node specific tests were copied to the Remotely node
            Context '[BootStrap] Test if the Node tests were copied' {

                It 'Should drop a file with format <NodeName>.<Describe_block>.Tests.ps1' {
                    "$($Global:Remotely.RemotelyNodePath)\$($env:ComputerName).Bits_Service_test.Tests.ps1" | 
                        Should Exist
                }

                It 'Should create a Pester NUnit report for the Node' {
                    "$($Global:Remotely.RemotelyNodePath)\$($env:ComputerName).xml" |
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
                        $Object.Tests[0].Name | Should Be 'Bits Service test'
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
                        $Object.Tests[0].Name | Should Be 'Bits Service test'
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

            Context 'Node data should Be populated in the Node PSSession' {
                $NodePSSession =  $Global:Remotely.SessionHashtable["$env:COMPUTERNAME"].session
                $NodeResult = Invoke-Command -Session $NodePSSession -ScriptBlock {return $Node}
                
                It "Should have `$Node variable defined in the Remote PSSession" {
                    $NodeResult | Should NOT BeNullOrEmpty
                }

                It "Should have the common properties from ConfigData" {
                    $NodeResult.DomainFQDN | Should Be 'Dexter.lab'
                }

                It 'Should have Node specific properties' {
                    $NodeResult.ServiceName | Should Be 'bits'
                    $NodeResult.Type | Should Be 'Compute'
                    $NodeResult.NodeName | Should Be "$env:COMPUTERNAME"
                }
            } 

        }

        Describe 'PSSession opened during Remotely run, persist.' -Tag Integration {
            
            Context 'Using the Get-RemoteSession function' {
                $RemoteSession = Get-RemoteSession

                It 'Should return the PSSession starting with name Remote-NodeName' {
                    $RemoteSession.Foreach({
                        $PSItem.Name | Should Match 'Remotely-*'
                    })
                }

                It 'Should return the PSSession in opened state' {
                    $RemoteSession.Foreach({
                    $PSItem.State  | Should BeExactly 'Opened'
                    }) 
                }
                
            }

            Context 'Using the global variable Remotely' {

                It 'Should have the PSSession maintained in the Session hashtable' {
                    $Global:Remotely.SessionHashTable | Should NOT BeNullOrEmpty
                    $Global:Remotely.SessionHashTable.ContainsKey('Localhost') | Should Be $True
                    $Global:Remotely.SessionHashTable.ContainsKey("$env:COMPUTERNAME") | Should Be $True
                }
            }
        }

        Describe 'Clear-RemoteSession' -Tag Integraion {

            Context 'Clear all open PSSessions after Remotely run' {
                Clear-RemoteSession

                It 'Should clear all Remotely PSSessions' {
                    Get-RemoteSession | Should BeNullOrEmpty
                    Get-PSSession -Name Remotely-* | Should BeNullOrEmpty
                }
            }

            Context 'Should update the global variable Remotely' {

                It 'Should clear out Session Hashtable' {
                    $Global:Remotely.SessionHashTable | Should  BeNullOrEmpty
                }

                It 'Should clear out the NodeMap' {
                    $Global:Remotely.NodeMap | Should BeNullOrEmpty
                }
            }
        }
    }
    catch {
        Clear-RemotelyNodePath
        Clear-RemoteSession
    }

}
