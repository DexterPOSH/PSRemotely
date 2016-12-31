if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}


$PSVersion = $PSVersionTable.PSVersion.Major
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

InModuleScope -ModuleName $ENV:BHProjectName {
    Describe 'PSRemotely' -Tag UnitTest {
        
        Context  'PSRemotely with no configuration data' {
            
            #Arrange
            Mock -CommandName Node -MockWith {}
            #Act
            PSRemotely {
                Node 'localhost' {
                    Describe 'DNStest' {
                        
                    }    
                } 
            } 
            
            # Assert
            It 'Should straight ahead execute the Body scriptblock ' {
                Assert-MockCalled -CommandName Node -times 1 -Exactly -Scope Context
            }
        }
        
        Context 'PSRemotely with Configuration data passed, Sessions not created' {
            # Arrange
            $ConfigData = @{
                AllNodes = @(
                    @{
                        NodeName='localhost';
                        Role = 'IIS'
                    }
                )
            }
            Mock Test-ConfigData -MockWith {}
            Mock Update-ConfigData -MockWith {$ConfigData}
            Mock CreateSessions -MockWith {}
            Mock Node -MockWith {}
            
            # act
            $out = try {
                PSRemotely -ConfigurationData $ConfigData {
                        Node $AllNodes.NodeName {
                            Describe 'DNStest' {
                                $DNSService = Get-Service -name DNSServer
                        
                                It 'Should have DNSService' {
                                    $DNSService | Should Not BeNullOrEmpty
                                }
                            }
                        }
                }
            }
            catch {
                $noSessionCreated = $PSitem
            }
            
            # Assert
            It 'Should Test the config data passed to it' {
                Assert-MockCalled -CommandName Test-ConfigData -times 1 -Exactly -Scope Context
            }
            
            It 'Should update the config data passed to it' {
                Assert-MockCalled -CommandName Update-ConfigData -times 1 -Exactly -Scope Context
            }
            
            
            It 'Should call CreateSessions to create underlying Remoting session to the node' {
                Assert-MockCalled -CommandName CreateSessions -Times 1 -Exactly -Scope Context
            }
            
            It 'Throws error that no Session created, because of mock' {
                $NoSessionCreated | Should Not BeNullOrEmpty
            }

            It 'Should NOT call the body script block at the end' {
                Assert-MockCalled -CommandName Node -Times 0 -Exactly -Scope Context     
            }
            
        } 
        
        # More context blocks to be added 
    }    

}
