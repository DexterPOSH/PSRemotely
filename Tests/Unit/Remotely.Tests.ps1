$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}
if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}


$PSVersion = $PSVersionTable.PSVersion.Major
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

InModuleScope -ModuleName $ENV:BHProjectName {
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
