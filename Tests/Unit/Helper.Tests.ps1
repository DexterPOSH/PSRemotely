if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}


$PSVersion = $PSVersionTable.PSVersion.Major
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force




InModuleScope -ModuleName $ENV:BHProjectName {
    
    Describe 'Start-RemotelyJobProcessing' {

        Context "When multiple remotely jobs are to be processed" {
            # Arrange
            Mock -Command ProcessRemotelyJob -MockWith {return $true}
            
            Mock -Command ProcessRemotelyOutputToJSON -MockWith {}
            
            $dummyInput = @{
                'Node1' = [pscustomobject]@{State='Completed'}; 
                'Node2' = [pscustomobject]@{State='Failed'};
            }

            # Act & Assert
            It 'Should process each Node(s) remotely job' {
                {Start-RemotelyJobProcessing -InputObject $dummyInput -Verbose} | Should Not throw
                Assert-MockCalled -Command ProcessRemotelyJob -Times 2 -Exactly
                Assert-MockCalled -Command ProcessRemotelyOutputToJSON -Times 2 -Exactly
            }
        }


        Context "When multiple remotely jobs are to be processed and one of the Jobs fails" {
            # Arrange
            Mock -Command ProcessRemotelyJob -MockWith {throw 'Error'}
            
            Mock -Command ProcessRemotelyOutputToJSON -MockWith {}
            
            $dummyInput = @{
                'Node1' = [pscustomobject]@{State='Completed'}; 
                'Node2' = [pscustomobject]@{State='Failed'};
            }

            # Act & Assert
            It 'Should throw back the error' {
                {Start-RemotelyJobProcessing -InputObject $dummyInput -Verbose} | Should throw 'Error'
                Assert-MockCalled -Command ProcessRemotelyJob -Times 1 -Exactly
                Assert-MockCalled -Command ProcessRemotelyOutputToJSON -Times 0 -Exactly
            }
        }

        Context "When multiple remotely jobs are to be processed and json processing fails for a node" {
            # Arrange
            Mock -Command ProcessRemotelyJob -MockWith {return $true}
            
            Mock -Command ProcessRemotelyOutputToJSON -MockWith {throw 'Error'}
            
            $dummyInput = @{
                'Node1' = [pscustomobject]@{State='Completed'}; 
                'Node2' = [pscustomobject]@{State='Failed'};
            }

            # Act & Assert
            It 'Should throw back the error to parent' {
                {Start-RemotelyJobProcessing -InputObject $dummyInput -Verbose} | Should throw 'Error'
                Assert-MockCalled -Command ProcessRemotelyJob -Times 1 -Exactly
                Assert-MockCalled -Command ProcessRemotelyOutputToJSON -Times 1 -Exactly
            }
        }	
    }
}