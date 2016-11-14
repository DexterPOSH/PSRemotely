$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}

$PSVersion = $PSVersionTable.PSVersion.Major
Import-Module $PSScriptRoot\..\..\Remotely -Force

InModuleScope -ModuleName Remotely {
    
    Describe 'Get-TestNameAndTestBlock' -Tag UnitTest {
        
        Context 'No Describe block in the Input, Input should have a Describe block' {
            
            # Arrange
            $Input ="Write-Host 'RandomString' "
            Mock -CommandName Get-ASTFromInput -MockWith {
                New-Module -ScriptBlock {
                    Function FindAll {
                        return $Null
                    }
                }
            }
            
            # Act & Assert
            It 'Should throw Error' {
                { Get-TestNameAndTestBlock -Content $Input } | 
                    Should Throw 'Describe block not found in the Test Body.'
            }   
        }

        Context 'No test name specified to the Describe block' {

            #Arrange
            $InputScript  = {
                Describe  {

                }
            }

            # Act & Assert 
        }

    }    
}
    

