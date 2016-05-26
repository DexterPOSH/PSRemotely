$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}

$PSVersion = $PSVersionTable.PSVersion.Major
Import-Module $PSScriptRoot\..\Remotely -Force

Describe "Add-Numbers PS$PSVersion" {
   
    It "can execute script" {
            Remotely { 1 + 1 } | Should Be 2
        }

    It "can return an array" {
        $returnObjs = Remotely { 1..10 }
        $returnObjs.count | Should Be 10
    }

    It "can return a hashtable" {
        $returnObjs = Remotely { @{Value = 2} }
        $returnObjs["Value"] | Should Be 2
    }

    It "can get verbose message" {
        $output = Remotely { Write-Verbose -Verbose "Verbose Message" }
        $output.GetVerbose() | Should Be "Verbose Message"
    }

    It "can get error message" {
        $output = Remotely { Write-Error "Error Message" }
        $output.GetError() | Should Be "Error Message"
    }

    It "can get warning message" {
        $output = Remotely { Write-Warning "Warning Message" }
        $output.GetWarning() | Should Be "Warning Message"
    }

    It "can get debug message" {
        $output = Remotely { 
                $originalPreference = $DebugPreference
                $DebugPreference = "continue"
                Write-Debug "Debug Message" 
                $DebugPreference = $originalPreference
            }
        $output.GetDebugOutput() | Should Be "Debug Message"
    }

    It "can get progress message" {
        $output = Remotely { Write-Progress -Activity "Test" -Status "Testing" -Id 1 -PercentComplete 100 -SecondsRemaining 0 }
        $output.GetProgressOutput().Activity | Should Be "Test"
        $output.GetProgressOutput().StatusDescription | Should Be "Testing"
        $output.GetProgressOutput().ActivityId | Should Be 1
    }

    It 'can return $false as a value' {
        $output = Remotely { $false }
        $output | Should Be $false
    }

    It 'can return throw messages' {
        $output = Remotely { throw 'bad' }
        $output.GetError().FullyQualifiedErrorId | Should Be 'bad'
    }
    
    It "can get remote sessions" {
        Remotely { 1 + 1 } | Should Be 2
        $remoteSessions = Get-RemoteSession

        $remoteSessions | % { $remoteSessions.Name -match "Remotely"  | Should Be $true} 
    }
    
    It "can pass parameters to remote block" {
        $num = 10
        $process = Remotely { param($number) $number + 1 } -ArgumentList $num
        $process | Should Be 11
    }

    It "can get target of the remotely block" {
        $output = Remotely { 1 } 
        $output.RemotelyTarget | Should Be "localhost"
    }

    It "can handle delete sessions" {
        Remotely { 1 + 1 } | Should Be 2
        $previousSession = Get-RemoteSession 
        $previousSession | Remove-PSSession

        ##New session should be created
        Remotely { 1 + 1 } | Should Be 2
        $newSession = Get-RemoteSession
        $previousSession.Name | Should Not Be $newSession.Name
    }
    
    It "can execute against more than 1 remote machines" {
        $configFile = (join-path $PSScriptRoot 'machineConfig.csv')
        $configContent = @([pscustomobject] @{ComputerName = "localhost" }, [pscustomobject] @{ComputerName = "." }) | ConvertTo-Csv -NoTypeInformation
        $configContent | Out-File -FilePath $configFile -Force
        
        try
        {
            $results = Remotely { 1 + 1 }  
            $results.Count | Should Be 2
        
            foreach($result in $results)
            {
                $result | Should Be 2 
            }
        }
        catch
        {
            $_.FullyQualifiedErrorId | Should Be $null
        }
        finally
        {
            Remove-Item $configFile -ErrorAction SilentlyContinue -Force
        }
    }
    
    It "can clear remote sessions" {
        Clear-RemoteSession
        Get-PSSession -Name Remotely* | Should Be $null                
    }
}

InModuleScope -ModuleName Remotely {
    Describe 'Remotely' -Tag UnitTest {
        
        Context  'Remotely with no configuration data' {
            
            #Arrange
            Mock -CommandName Node -MockWith {}
            #Act
            Remotely {
                Node 'localhost' {
                    Describe 'DNStest' {
                        
                    }    
                } 
            } 
            
            # Assert
            It 'Should straight ahead execute the Body scriptblock ' {
                Assert-MockCalled -CommandName Node -times 1 -Exactly -Scope It
            }
        }
        
        Context 'Remotely with Configuration data passed' {
            # Arrange
            $ConfigData = @{
                AllNodes = @(
                    {
                        NodeName='localhost';
                        Role = 'IIS'
                    }
                )
            }
            Mock Test-ConfigData -MockWith {}
            Mock Update-ConfigData -MockWith {}
            Mock New-Variable -ParameterFilter {($Name -eq 'AllNodes') -and ($scope -eq 'Script')}
            Mock New-Variable -ParameterFilter {($Name -eq 'RemotelyNodeMap') -and ($scope -eq 'Script')}
            Mock Node -MockWith {}
            
            # act
            Remotely -ConfigurationData $ConfigData {
                Node $AllNodes.NodeName {
                    Describe 'DNStest' {
                        $DNSService = Get-Service -name DNSServer
                        
                        It 'Should have DNSService' {
                            $DNSService | Should Not BeNullOrEmpty
                        }
                    }
                }
            }
            
            # Assert
            It 'Should Test the config data passed to it' {
                Assert-MockCalled -CommandName Test-ConfigData -times 1 -Exactly -Scope Context
            }
            
            It 'Should update the config data passed to it' {
                Assert-MockCalled -CommandName Update-ConfigData -times 1 -Exactly -Scope Context
            }
            
            It 'Should create a script scope variable named AllNodes' {
                Assert-MockCalled -CommandName New-Variable -ParameterFilter {($Name -eq 'AllNodes') -and ($scope -eq 'Script')}
            }
            
            It 'Should create a remotelyNodeMap script scope variable' {
                Assert-MockCalled -CommandName New-Variable -ParameterFilter {($Name -eq 'RemotelyNodeMap') -and ($scope -eq 'Script')}
            }
            
            It 'Should call the body script block at the end' {
                 Assert-MockCalled -CommandName Node -Times 1 -Exactly -Scope Context     
            }
            
        }  
    }    
}
