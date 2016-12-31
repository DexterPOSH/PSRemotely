if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..\..
}


$PSVersion = $PSVersionTable.PSVersion.Major
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

InModuleScope -ModuleName $ENV:BHProjectName {
    
    Describe 'Get-TestNameAndTestBlock' -Tag UnitTest {
        
        Context 'No Describe block in the Input, Input should have a Describe block' {
            
            # Arrange
            $Input ="Write-Host 'RandomString'"
                        
            # Act & Assert
            It 'Should throw a customized Error about Describe block not found' {
                { Get-TestNameAndTestBlock -Content $Input } | 
                    Should Throw 'Describe block not found in the Test Body.'
            }

        }

        Context 'No test name specified to the Describe block' {

            #Arrange
            $InputScript  = {
                Describe  {
                    It 'Dummy' {}
                }
            }

            # Act & Assert 
            It 'Should throw a customized error' {
                { Get-TestNameAndTestBlock -Content $InputScript } |
                    Should Throw 'TestName passed to Describe block should be a string'
            }
        }

        Context 'Describe block with test name passed' {
            
            $InputScript = {
                Describe 'TestIPconfig' {
                    It 'dummy' {}
                }
            }

            # Act & Assert 
            $HashTable =  Get-TestNameAndTestBlock -Content $InputScript 
            
            $HashTable.GetEnumerator() | Foreach-Object {

                It 'Should return the name of the test as they key in hashtable' {
                     $PSitem.Key | Should Be 'TestIPConfig'
                }

                It 'Should return the test block as the value in the hashtable' {
                    $PSitem.Value.Trim() | Should Be $InputScript.ToString().trim()
                }
            }
        }

        Context 'Describe block with test name and tags passed' {
            
            $InputScript = {
                Describe 'dummy' -tag test   {
                    It 'should work' {
                        $true | Should be $true
                    }
                }
            }

            # Act & Assert 
            $HashTable =  Get-TestNameAndTestBlock -Content $InputScript 
            
            $HashTable.GetEnumerator() | Foreach-Object {

                It 'Should return the name of the test as they key in hashtable' {
                     $PSitem.Key | Should Be 'dummy'
                }

                It 'Should return the test block as the value in the hashtable' {
                    $PSitem.Value.Trim() | Should Be $InputScript.ToString().trim()
                }
            }
        }
    }    
}
    

